json.moves @moves do |move|
  json.partial! "api/v1/moves/move", move: move
end

json.meta do
  json.page  @meta[:page]
  json.per   @meta[:per]
  json.total @meta[:total]
end
