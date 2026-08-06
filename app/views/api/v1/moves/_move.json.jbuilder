json.id                       move.id
json.uuid                     move.uuid
json.title                    move.title
json.description              move.description
json.stage                    move.stage
json.move_type                move.move_type
json.ev_score                 move.ev_score
json.recommendation           move.recommendation
json.subjective_probability   move.subjective_probability
json.effort_minutes           move.effort_minutes
json.payoff_value_normalized  move.payoff_value_normalized
json.payoff_type              move.payoff_type
json.due_date                 move.due_date
json.campaign_id              move.campaign_id
json.created_at               move.created_at
json.updated_at               move.updated_at

# delegation_id (the callback capability nonce) and delegation_result are
# deliberately OMITTED here — they're only returned by the delegation-scoped
# endpoints (delegate/claim/callback/queue), not to a general moves:read token.
json.delegation do
  json.assignee          move.assignee
  json.delegation_state  move.delegation_state
  json.delegated_at      move.delegated_at
  json.reported_at       move.reported_at
end
