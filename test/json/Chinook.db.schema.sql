-- Uncomment following line if running in the context when Flexilite is not yet loaded
-- select load_extension('libFlexilite');

select flexi('configure');

select flexi('load', '../test/json/Chinook.db.schema.json');

create virtual table if not exists [PlaylistTrack]
                using flexi_rel ([PlaylistId], [TrackId], [Playlist] hidden, [Track] hidden);

                