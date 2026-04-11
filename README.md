# nominatim_filter

EmergenceSystem filter that geocodes place names and addresses using OpenStreetMap Nominatim. No API key required.

## Input

```json
{"query": "Eiffel Tower, Paris"}
```

| Field     | Type    | Default | Description                   |
|-----------|---------|---------|-------------------------------|
| `query`   | string  | —       | Place name or address         |
| `address` | string  | —       | Alias for `query`             |
| `timeout` | integer | `10`    | HTTP timeout in seconds       |

## Output

Up to 10 embryos, one per result:

```json
{
  "properties": {
    "url":       "https://www.openstreetmap.org/search?query=...",
    "resume":    "Eiffel Tower, 5, Avenue Anatole France, Paris, Île-de-France, France",
    "latitude":  "48.8583701",
    "longitude": "2.2922926",
    "source":    "nominatim.openstreetmap.org"
  }
}
```

## Capabilities

`nominatim`, `geocoding`, `openstreetmap`, `geo`, `location`

## Usage

```bash
rebar3 shell
```

## License

Apache-2.0
