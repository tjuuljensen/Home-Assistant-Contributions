# Alarm fra 112 Odin

**Original kode**: Erik Maach Madsen (https://pastebin.com/KSgMNzUp).


**Formål**: At vise alarmer fra det danske beredskab fra ODIN 112. 


**Ændringer fra original**: 

- Datoformat fra RSS er ændret.
- Der vises flere forskellige udrykningstyper.
- Visning er i tabelformat .



## Forudsætning
Data hentes via RSS med feedparser (https://github.com/custom-components/feedparser/tree/master).

[![Opens your Home Assistant instance and the feedparser integration from Home Assistant Community Store.](https://my.home-assistant.io/badges/hacs_repository.svg)](https://my.home-assistant.io/redirect/hacs_repository/?category=Integration&repository=feedparser&owner=custom-components)


## Installation
1. Gå til: http://www.odin.dk/RSS/Getberedskab.aspx
2. Vælg beredskab
3. Skriv beredskabsID ned (står i enden af linket, der kommer frem)
4. Tryk på RSS ikonet
5. Find station navn (hvis din station ikke står der, har der ikke været nogle alarmer og du må tjekke ind imellem om der har været alarm)
6. Opret sensor i configuration.yaml og erstat bereskabsID med dit eget fra pk. 3
    ```
    sensor:
      - platform: feedparser
        name: 112 ODIN
        feed_url: http://www.odin.dk/RSS/RSS.aspx?beredskabsID=0000
        date_format: '%Y-%m-%d %H:%M:%S%z' 
        scan_interval:
          minutes: 10
    ```
7. Genstart Home Assistant
8. Opret markdown kort, eks. nedenfor og konfigurer værdierne, så kortet viser de ønskede data.
   - Sæt 'title' (overskrift på kortet).
   - Sæt 'station' ved at erstatte XYZ med dit stations navn fra pkt. 5. Ønsker du flere stationer bliver vist kan XYZ ændres til f.eks: stationsnavn1|stationsnavn2|stationsnavn3
   - Definer 'odin_entity' - din feedparser entitet med data fra ODIN.
   - 'remove_station' er en boolean. Som udgangspunkt fjerner denne alt efter "Station:" fra den originale ODIN summary tekst.
   - Definer hvor mange timer ('hours_cutoff'), som kortet skal vise data for.

    ```
    type: markdown
    content: >-
      {# 
       # Configure the card like this:
       # 
       # title: Header. For display only. 
       # station: The stations(s) to display. Multiple entries can be delimited with a pipe, ex.: 'Roskilde|Jyllinge'
       # odin_entity: Feedparser entity. Expects default date formatting - '%Y-%m-%d %H:%M:%S%z' 
       # remove_station: Remove station name from report text.
       # hours_cutoff: How many hours to display.
       #}
      {% set title='Beredskab XYZ' %}
      {% set station = 'XYZ' %} 
      {% set odin_entity = 'sensor.odin_xyz_feed' %}
      {% set remove_station = true %}
      {% set hours_cutoff = 24 %}

      {# Card logic #}
      {%- set entries = state_attr(odin_entity, 'entries') or [] %}  
      {% set date_limit = (now() - timedelta(hours=hours_cutoff)) | string %}  
      {% set filtered = entries
          | selectattr('published', 'gt', date_limit)
          | selectattr('summary', 'search', '(?i)('+station+')')
          | selectattr('summary', 'search', '(?i)(brand|redning|redn.|drukne|forurening|fuh|gas|fly)')
          | list
      %}
      ## {{ title }} 🚨
      {% if (filtered) | length > 0 %}
      <table>
      <thead>
      <tr>
          <th align='left'>Time</th>
          <th align='center'></th>
          <th align='left'>First Report</th>
        </tr>
        </thead>
        <tbody>
      {% endif %}
      {%- for e in filtered[:5] %}
      <tr> 
      <td>{{ (e.published | as_datetime).strftime('%a %H:%M')}}</td>
      <td>
        {%- set s = e.summary.lower() -%}
        {%- if 'brandalarm' in s -%}
          🔔
        {%- elif 'brand' in s -%}
          🔥
        {%- elif 'redning' in s or 'redn.' in s -%}
          🚑
        {%- elif 'forurening' in s -%}
          🫗
        {%- elif 'fuh' in s -%}
          💥   
        {%- elif 'drukne' in s -%}
          🛟
        {%- elif 'gas' in s -%}
          ♨ 
        {%- elif 'fly' in s -%}
          🛬
        {% else %}
          🚨
        {%- endif -%} 
      </td>
      <td>{{ iif(remove_station,e.summary.rsplit('Station:', 1)[0] | trim,e.summary).rsplit('Førstemelding:')[1] | trim }}</td>
      </tr>
      {% else %}

        _No events in the last {{hours_cutoff}} hours._

      {% endfor %}
      </tbody></table>

      Source: [Beredskabsstyrelsen](http://www.odin.dk/112puls/ "ODIN - Online Dataregistrerings- og INdberetningssystem")
      ```

## Baggrund

Følgende er en liste over meldinger fra ODIN, og hvordan disse kan oversættes til kategorier:

### Oversættelse af beskeder fra ODIN

* "FUH" -> Færdselsuheld 
* "Brandalarm" -> Alarm
* "Bygn.brand" -> Brand
* "brand-" -> Brand
* "-Brand" -> Brand
* "Naturbrand" -> Brand
* "Mindre brand" -> Brand
* "Drukneulykke" -> Drukneulykke
* "forurening" -> Forurening (ofte set ifm. FUH)
* "ISL-Forespørgsel" -> Indsatsleder
* "Fly" -> Fly
* "Redn." -> Redning
* "Redning" -> Redning
* "Forurening" -> Forurening
* "Min. forurening" -> Forurening