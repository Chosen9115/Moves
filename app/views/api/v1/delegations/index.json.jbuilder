json.moves @moves do |move|
  json.partial! "api/v1/moves/move", move: move
  # The agent needs the nonce to call back; it's scoped to this delegation:read queue.
  json.delegation_id     move.delegation_id
  json.delegation_result move.delegation_result
end
