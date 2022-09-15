Here are some notes on how to do development on `ActiveEnquo`.

# Setup

1. Checkout the repo.

2. Ensure you've got a Ruby 2.7+ installation as your default Ruby.

3. Run `bundle install`.

... and you're ready to go.


# Running the test suite

Run the test suite with `rake spec`.

You'll need a Postgres database with the [`pg_enquo`](https://github.com/enquo/pg_enquo) extension installed.
Use the [standard `PG*` environment variables](https://www.postgresql.org/docs/current/libpq-envars.html) to control the where the test suite connects to.
If you're running a "test" `pg_enquo` database with `cargo pgx run pgNN`, then this should do the trick:

```sh
$ PGHOST=localhost PGDATABASE=pg_enquo PGPORT=288NN rake spec
```
