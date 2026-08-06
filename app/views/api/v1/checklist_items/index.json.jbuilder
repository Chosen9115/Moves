json.checklist_items @checklist_items do |checklist_item|
  json.partial! "api/v1/checklist_items/checklist_item", checklist_item: checklist_item
end
