json.partial! "api/v1/moves/move", move: @move

# Delegation-scoped response: include the callback capability nonce + result,
# which the shared _move partial omits from general moves:read output.
json.delegation_id     @move.delegation_id
json.delegation_result @move.delegation_result
