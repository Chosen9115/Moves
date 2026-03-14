class SettingsController < ApplicationController
  def show
    @preference = AppPreference.current
  end

  def update
    @preference = AppPreference.current

    attrs = settings_params.to_h
    if attrs["openai_api_key"]&.start_with?("sk-\u2022\u2022")
      attrs.delete("openai_api_key")
    end

    if @preference.update(attrs)
      redirect_to settings_path, notice: "Settings updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:app_preference).permit(:openai_api_key, :openai_model)
  end
end
