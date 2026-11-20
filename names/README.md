# Names that other apps write

Each `.tsv` file lists the exercise names that one app writes in its export.
The `slug` column names the record that the name must match. An empty slug
means that no record matches the name yet.

- `strong.tsv` holds the names in one real Strong export.
- `hevy.tsv` is empty until a copy of Hevy's exercise catalog is available.

The REDOUBLE app copies these files into its tests and runs its own matcher
over them. Thus a release that breaks a match fails the app's tests.
