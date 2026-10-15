"""Update one Home Assistant entity state and its state attributes.

This file is executed by the Home Assistant ``python_script`` integration. It
does not use imports and changes only the Home Assistant state-machine copy of
the entity. An integration may recreate an edited attribute on its next update.

Inputs:
    entity_id (str, required): Entity whose state should be changed.
    state (str, optional): Replacement state. Omit it to keep the current state.
    delete_attribute (str, optional): Attribute name to remove from the current
        attribute dictionary. The operation is idempotent if it is absent.
    Any other key/value pair becomes an attribute update.

Examples:
    Call ``python_script.set_state`` with::

        entity_id: input_boolean.test_switch
        state: "on"

    Call ``python_script.set_state`` with::

        entity_id: binary_sensor.team_tracker_fck
        superliga_abbr: FCK

    Call ``python_script.set_state`` with::

        entity_id: sensor.example
        delete_attribute: obsolete_attribute

Side effects:
    Calls ``hass.states.set`` with the current attributes plus requested
    updates, except for ``delete_attribute`` which is removed first.

Compatibility:
    Home Assistant ``python_script`` integration. The state update is transient
    for integration-owned entities and is not a device or registry edit.

Author:
    Torsten Juul-Jensen

Version: 1.2.0

Changelog:
    1.2.0 - Add idempotent delete_attribute support and input/entity checks.
    1.1 - Document the original dynamic state and attribute behavior.
"""

SCRIPT_VERSION = "1.2.0"

entity_id = data.get("entity_id")
if not isinstance(entity_id, str) or not entity_id.strip():
    logger.warning("set_state requires a non-empty string entity_id")
else:
    entity = hass.states.get(entity_id)
    if entity is None:
        logger.warning("set_state cannot find entity '%s'", entity_id)
    else:
        state = entity.state
        attributes = entity.attributes.copy()

        delete_attribute = data.get("delete_attribute")
        if delete_attribute is not None:
            if not isinstance(delete_attribute, str) or not delete_attribute.strip():
                logger.warning("delete_attribute must be a non-empty string")
            elif delete_attribute in attributes:
                del attributes[delete_attribute]
                logger.debug(
                    "Removed attribute '%s' from '%s'",
                    delete_attribute,
                    entity_id,
                )
            else:
                logger.debug(
                    "Attribute '%s' is not present on '%s'",
                    delete_attribute,
                    entity_id,
                )

        for key in data:
            if key in ("entity_id", "delete_attribute"):
                continue

            value = data.get(key)
            logger.debug("set_state input: %s=%s", key, value)
            if key == "state":
                if value is not None:
                    state = value
            else:
                attributes[key] = value

        hass.states.set(entity_id, state, attributes)
