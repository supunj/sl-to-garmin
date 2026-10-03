# pg/experiments

Unvetted SQL experiments for the PostGIS cleansing stage.

- Files here are **never** run by a normal `./build_map.sh --pg-cleanse`
  build. They run only with `./build_map.sh --pg-cleanse --pg-experiments`
  (or `./cleanse_data.sh --experiments`), after the vetted rules in
  `pg/cleanse/`.
- Use this directory to try out cleansing ideas against the scratch
  database (`osm_build` by default) without affecting production builds.
- **Promotion path**: once an experiment is verified (inspect the cleansed
  PBF, e.g. with osmium/osmosis tag counts), move it to
  `pg/cleanse/NN_descriptive_name.sql` with a header comment explaining the
  rule, and delete it from here.
- Rules in `pg/cleanse/` run in filename order — use the numeric prefix to
  control ordering between rules.
