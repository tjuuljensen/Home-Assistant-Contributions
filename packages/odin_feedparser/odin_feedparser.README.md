# ODIN Feedparser Package

The example feeds cover Østjyllands Brandvæsen (Aarhus) and Beredskab Fyn
(Odense). Select feeds and station filters for the areas you want to follow.
The YAML header includes a Markdown dashboard card example.

## Installation

1. Install the [Feedparser custom integration](https://github.com/custom-components/feedparser).
2. Enable Home Assistant packages and copy
   [`odin_feedparser.yaml`](odin_feedparser.yaml) into `/config/packages/`.
3. Copy [`odin.jinja`](../../custom_templates/odin.jinja) into
   `/config/custom_templates/odin.jinja` and reload custom templates.
4. Set the desired feeds and station filters consistently in sensor names,
   unique IDs, helper IDs, trigger/entity references, polling defaults/buttons,
   and the dashboard example. Fresh installations use the documented entity
   names; existing entity registry names may differ and need checking.
5. Check the Home Assistant configuration and restart to load the package.
   The YAML header contains a Markdown dashboard card example.

Packages can be enabled in `configuration.yaml` with:

```yaml
homeassistant:
  packages: !include_dir_named packages
```

Merge this into an existing `homeassistant:` block if you already have one.

## Public example feeds

| Fire service | Feed ID | Station filter |
| --- | --- | --- |
| Østjyllands Brandvæsen | `1212` | `Aarhus` |
| Beredskab Fyn | `1207` | `Odense` |

IDs come from the [Beredskabsstyrelsen RSS address list](https://www.brs.dk/da/nyheder/2016/nye-internetadresser-til-rss-feed-for-1-1-2-alarmer/).
Station areas are documented by [Østjyllands Brandvæsen](https://www.ostbv.dk/brandstationer)
and [Beredskab Fyn](https://beredskabfyn.dk/beredskab). The filters match city
names within report text, potentially covering multiple stations. The ODIN
endpoint could not be reached during validation on 2026-10-15;
verify current feed IDs and exact station text with the
[ODIN feed selector](http://www.odin.dk/RSS/Getberedskab.aspx) before relying on
these examples.

## What This Package Does

`odin_feedparser.yaml` consumes ODIN RSS feed entities from the Feedparser custom integration and exposes normalized incident summary sensors.

The package is primarily used for dashboard badges, Markdown cards, conditional cards, and simple alerting around selected fire station events.

## Files and configuration

| Origin in this repo | Destination in your config | Purpose | Example / configuration |
| --- | --- | --- | --- |
| [odin_feedparser.yaml](odin_feedparser.yaml) | `/config/packages/odin_feedparser.yaml` | Required feed sensors, helpers, and polling scripts | Markdown dashboard example and settings in the YAML header |
| [odin.jinja](../../custom_templates/odin.jinja) | `/config/custom_templates/odin.jinja` | Required incident parsing/display macros | Imported by the package; reload custom templates after installing |
| [Entity reference](odin_feedparser.reference.md) | Documentation only | Package entities and current behavior | Adapt its example entity IDs consistently when choosing other feeds |

The Feedparser custom integration is required separately.

## Validation

After editing this package, run Home Assistant's configuration check in your
own installation before restarting.

After editing `/config/custom_templates/odin.jinja`, reload custom templates from Developer Tools or call `homeassistant.reload_custom_templates`.

## Attribution

The original dashboard example was based on code by
[Erik Maach Madsen](https://pastebin.com/KSgMNzUp).
