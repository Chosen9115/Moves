require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  test "layout head advertises the PWA manifest, theme color, and icons" do
    sign_in_as users(:one)
    get root_path
    assert_response :success

    assert_select "link[rel=manifest][href='/manifest.json']"
    assert_select "meta[name=?][content=?]", "theme-color", "#1E5C42"
    assert_select "link[rel=?][href=?]", "apple-touch-icon", "/icons/apple-touch-icon.png"
  end

  test "manifest.json is valid and lists installable icons (192, 512, maskable)" do
    manifest = JSON.parse(File.read(Rails.root.join("public/manifest.json")))

    assert_equal "standalone", manifest["display"]
    assert_equal "/focus", manifest["start_url"]
    assert_equal "#1E5C42", manifest["theme_color"]

    sizes = manifest["icons"].map { |i| i["sizes"] }
    assert_includes sizes, "192x192"
    assert_includes sizes, "512x512"
    assert manifest["icons"].any? { |i| i["purpose"] == "maskable" }, "needs a maskable icon"

    %w[icon-192.png icon-512.png icon-512-maskable.png apple-touch-icon.png].each do |file|
      assert File.exist?(Rails.root.join("public/icons/#{file}")), "public/icons/#{file} is missing"
    end
  end

  test "service worker exists, is fetch-driven, and never caches API or mutations" do
    sw = File.read(Rails.root.join("public/service-worker.js"))
    assert_match(/addEventListener\("fetch"/, sw)
    assert_match(%r{startsWith\("/api/"\)}, sw, "must skip API requests")
    assert_match(/request\.method !== "GET"/, sw, "must skip non-GET (mutations)")
    assert File.exist?(Rails.root.join("public/offline.html"))
  end

  test "service worker never caches HTML — only static assets, no redirects" do
    sw = File.read(Rails.root.join("public/service-worker.js"))
    # Only genuinely-static destinations are cacheable (no HTML documents).
    assert_match(/STATIC_DESTINATIONS/, sw)
    assert_match(/isStaticAsset/, sw)
    # Navigations go to the network with an offline SHELL fallback, not a cached page.
    assert_match(%r{caches\.match\("/offline\.html"\)}, sw)
    # A login-redirect response must not be cached and pinned.
    assert_match(/!response\.redirected/, sw)
  end
end
