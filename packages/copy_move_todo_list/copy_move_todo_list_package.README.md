# Copy/Move To-do List Package

Active

Path references in this document:

| Context | Package path |
| --- | --- |
| Home Assistant runtime | `/config/packages/copy_move_todo_list_package.yaml` |

## What This Package Does

`copy_move_todo_list_package.yaml` exposes one reusable script:

- `script.todo_list_copy`

The script copies items from one Home Assistant `todo` entity to another.

It can:

1. Copy all items from a source list to a destination list.
2. Copy only selected item states with a status filter.
3. Move items instead of copying by deleting them from the source after the destination entry has been created.
4. Preserve status, description, and due date/due datetime when those fields are available on the source item.

This package only defines the script. It does not create helpers, automations, dashboards, or sensors.

## Exposed Script

- `script.todo_list_copy`
  - Alias: `To-do list: Copy/move list`
  - Mode: `queued`

### Script Fields

- `source`
  - Required `todo` entity to copy from.
  - Example: `todo.shopping_list`
- `destination`
  - Required `todo` entity to copy to.
  - Example: `todo.weekend_shopping`
- `filter`
  - Optional multi-select list of statuses to include.
  - Allowed values: `completed`, `needs_action`
  - Default: both values
- `move`
  - Optional boolean.
  - `false` copies items and leaves the source unchanged.
  - `true` removes each copied item from the source after the destination item has been created and updated.

## Script Flow

The script runs in this order:

1. Stops immediately if `source` and `destination` are the same entity.
2. Stops immediately if `filter` is defined but empty.
3. Calls `todo.get_items` on the source list.
   - If `filter` is not defined, it requests all items.
   - Otherwise it requests only the selected statuses.
4. Loops through the returned items.
5. For each item, it:
   - adds the summary to the destination list
   - updates the destination item status
   - updates description if present
   - updates either `due_date` or `due_datetime` if present
6. If `move` is `true`, it removes the item from the source list after the destination updates.

## What Gets Preserved

For each copied item, the script attempts to preserve:

- summary
- status
- description
- due date
- due datetime

The script decides between `due_date` and `due_datetime` by checking the length of the returned `due` value:

- length `10` -> treated as a date-only value such as `2025-02-18`
- anything else -> treated as a datetime value

## Known Limitations

These limitations come from both the package description and the way the script identifies items:

- Destination items are matched by summary text, not by a unique item id.
- If the destination list already contains an item with the same summary, the script does not overwrite it.
- Repeated summaries can therefore produce duplicates in the destination list.
- Items with trailing spaces in the summary can fail because the current Home Assistant to-do actions are name-based.
- `move: true` also removes by summary text, so repeated source summaries are inherently less predictable than unique summaries.

Practical recommendation:

- Keep to-do item summaries unique when using this script.
- Normalize item names before moving large batches between lists.

## Example Calls

Copy everything from one list to another:

```yaml
action: script.todo_list_copy
data:
  source: todo.shopping_list
  destination: todo.weekend_shopping
```

Copy only incomplete items:

```yaml
action: script.todo_list_copy
data:
  source: todo.inbox
  destination: todo.today
  filter:
    - needs_action
```

Move completed items into an archive list:

```yaml
action: script.todo_list_copy
data:
  source: todo.household
  destination: todo.household_archive
  filter:
    - completed
  move: true
```

## Operational Notes

- If `filter` is omitted, the script copies all items returned by `todo.get_items`.
- If `filter` is present but empty, the script stops intentionally and does nothing.
- Because the script is `queued`, repeated calls wait in line instead of interrupting an active run.
- The package depends on Home Assistant's `todo` actions being available for the source and destination entities.

## Suggested Dashboard Exposure

If you want this script available in Lovelace, the simplest starting point is an `entities` card that exposes the script directly and lets you call it from scripts, buttons, or other automations.

Example:

```yaml
type: entities
title: To-do Tools
show_header_toggle: false
entities:
  - entity: script.todo_list_copy
```
