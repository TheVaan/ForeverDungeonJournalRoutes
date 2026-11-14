# Routes for DungeonJournal

Shows the dungeon routes of **Forever Dungeon Routes** directly on the dungeon maps of **DungeonJournal** (WoW Forever).

DungeonJournal and Forever Dungeon Routes each bring their own dungeon maps. With this addon you keep the DungeonJournal map and get the route on top of it, without opening a second map window.

## Features

- The active Forever Dungeon Routes route is drawn on the DungeonJournal map: the path with direction arrows, numbered boss stops, rares (`R`), optional stops (`+`), notes (`!`) and level changes (`>` / `<`).
- Click a level change marker to jump to the next level of the dungeon.
- Boss, rare and optional stops that you have ticked off in Forever Dungeon Routes appear dimmed with a check mark.
- Route menu (button `v` at the bottom right of the map): switch between the available routes of the dungeon, show or hide boss numbers and notes.
- Button `Route` at the bottom right of the map, or `/fdjr`, shows and hides the route. `/fdjr on` and `/fdjr off` work as well.
- Works on the journal's own map and on the world map inside a dungeon.
- Zooming and dragging the map work as usual; the route stays in place.
- DungeonJournal's RPG Mode is respected: bosses you have not discovered yet stay `???`.
- English and German.

## Requirements

- WoW Forever (interface 16001)
- DungeonJournal (by Exehn)
- Forever Dungeon Routes (by Checkov23)

Both are separate addons and are not part of this package. Routes are created, imported and edited in Forever Dungeon Routes (`/fdr`).

## What you should know

- Forever Dungeon Routes has no pulls or enemy positions, so none are shown. A route consists of paths, stops, notes and level changes.
- Only dungeons that have a map in DungeonJournal show a route. Lower and Upper Blackrock Spire and the raids have no DungeonJournal map; Shadowfang Keep shows the levels DungeonJournal has.
- DungeonJournal has no plugin interface. This addon hooks into its map rendering and can stop working after a DungeonJournal update. If something is missing, it switches itself off and tells you in the chat.

## Credits

- Forever Dungeon Routes by Checkov23 (MIT): the routes.
- DungeonJournal by Exehn: the maps.
- OpenMap Dungeon Routes (MIT): the same idea for OpenMap, which this addon follows.

## Development and releases

See [RELEASING.md](RELEASING.md).

## License

MIT, see [LICENSE](LICENSE).
