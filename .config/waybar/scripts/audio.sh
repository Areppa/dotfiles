#!/usr/bin/env bash

default_sink=$(pactl get-default-sink 2>/dev/null || true)
sinks_json=$(LC_NUMERIC=C pactl --format=json list sinks 2>/dev/null || printf '[]')

if ! printf '%s' "$sinks_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    sinks_json='[]'
fi

jq -c -n \
  --arg default "$default_sink" \
  --argjson sinks "$sinks_json" '
  def channel_volumes:
    [
      (.volume // {}
       | if type == "object" then to_entries[] else empty end
       | .value | objects | .value_percent? // empty
       | tostring | sub("%$"; "") | tonumber?)
    ];

  def volume_average:
    channel_volumes as $v
    | if ($v | length) == 0 then 0
      else ($v | add) / ($v | length)
      end;

  def volume_percent:
    (volume_average | round | tostring) + "%";

  def volume_icon:
    if .mute == true then "󰖁"
    elif volume_average < 34 then "󰕿"
    elif volume_average < 67 then "󰖀"
    else "󰕾"
    end;

  def port_text:
    .active_port // ""
    | if type == "object" then
        [.name // "", .description // "", .type // ""]
        | map(tostring) | join(" ")
      else tostring
      end;

  def is_headphones:
    ([.description // "", .name // "", port_text]
     | map(tostring) | join(" "))
    | test("headphone|headset|earbud|airpod"; "i");

  ($sinks
   | map(select(type == "object")
         | select(([.name // "", .description // ""] | join(" "))
                  | test("easy[[:space:]_-]*effects"; "i") | not))
  ) as $visible_sinks |

  ($visible_sinks | map(select(.name == $default)) | first) as $active |

  {
    text:
      (if ($active | type) != "object" then "󰕾"
       elif ($active | is_headphones) then
         "󰋋 " + ($active | volume_icon)
       else
         ($active | volume_icon)
       end),
    tooltip:
      (if ($visible_sinks | length) == 0 then "No audio outputs found"
       else
         ($visible_sinks
          | map(
              (if .name == $default then "●" else "○" end)
              + " " + volume_percent
              + " | " + (.description // .name // "Unknown output")
            )
          | join("\n"))
       end)
  }
'
