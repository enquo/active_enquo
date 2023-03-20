If you have data already in your database that you wish to protect using ActiveEnquo, you can migrate the data into an encrypted form.

There are two approaches that can be used:

* [Direct Migration](#data-migration-with-downtime), which is straightforward but involves application downtime; or

* [Live Migration](#live-data-migration), which is more complicated, but can be done while keeping the application available at all times.


# Data Migration (with Downtime)

If your application can withstand being down for a period of time, you can use a simple migration process that encrypts the data and modifies the application appropriate in a single pass.
It relies on their being a period with nothing accessing the column(s) being migrated, which usually means that the entire application (including background workers and periodic tasks) being shut down, before being restarted.
The total downtime will depend on how long it takes to encrypt and write all the data being migrated, which is mostly a function of the amount of data being stored.


## Step 1: Configure the Encrypted Column(s)

Create an ActiveRecord migration which renames the existing column and creates a new `enquo_*` column with the old name.
For example, if you already had a `date_of_birth` column, your migration would look like this:

```ruby
class EncryptUsersDateOfBirth < ActiveRecord::Migration[7.0]
  def change
    rename_column :users, :date_of_birth, :date_of_birth_plaintext
    add_column :users, :date_of_birth, :enquo_date
    User.enquo_encrypt_columns(date_of_birth_plaintext: :date_of_birth)
    remove_column :users, :date_of_birth_plaintext
  end
end
```

The `Model.encrypt_columns` method loads all the records in the table, and encrypts the value in the plaintext column and writes it to the corresponding encrypted column.

If you want to encrypt several columns in a single model, you can do so in a single migration, by renaming all the columns and adding `enquo_*` type columns, and then providing the mapping of all columns together in a single `Model.encrypt_columns` call.
This is the recommended approach, as it improves efficiency because the records only have to be loaded and saved once.

If you want to encrypt columns in multiple models in one downtime, just repeat the above steps for each table and model involved.


## Step 2: Modify Queries

When providing data to a query on an encrypted column, you need to make a call to `Model.enquo` in order to encrypt the value for querying.

To continue our `date_of_birth` example above, you need to find any queries that reference the `date_of_birth` column, and modify the code to pass the value for the `date_of_birth` column through a call to `User.enquo(:date_of_birth, <value>)`.

For a query that found all users with a date of birth equal to a query parameter, that originally looked like this:

```ruby
User.where(date_of_birth: params[:dob])
```

You'd modify it to look like this, instead:

```ruby
User.where(date_of_birth: User.enquo(:date_of_birth, params[:dob]))
```

If the value for the query was passed in as a positional parameter, you just encrypt the value the same way, so that a query might look like this:

```ruby
User.where("date_of_birth > ? OR date_of_birth IS NULL", User.enquo(:date_of_birth, params[:dob]))
```


## Step 3: Deploy

Once the above changes are all made and committed to revision control, it's time to commence the downtime.
Shutdown all the application servers, background job workers, and anything else that accesses the database, then perform a normal deployment -- running the database migration process before starting the application again.

The migration may take some time to run, if the table is large.


## Step 4: Enjoy Fully Encrypted Data

The column(s) you migrated are now fully protected by Enquo's queryable encryption.
Relax and enjoy your preferred beverage in celebration!


# Live Data Migration

Converting the data in a column to be fully encrypted, while avoiding any application downtime, requires making several changes to the application and database schema in alternating sequence.
This is necessary to ensure that parts of the application stack running both older and newer code versions can work with the database schema in place at all times.

> # WORK IN PROGRESS
>
> This section has not been written out in detail.
> The short version is:
>
> 1. Rename the unencrypted column:
>   1. `create_column :users, :date_of_birth_plaintext, :date`
>   2. Modify the model to write changes to `date_of_birth` to `date_of_birth_plaintext` as well
>   3. Deploy
>   4. Migration to copy all `date_of_birth` values to `date_of_birth_plaintext`
>   5. Deploy
>   6. Modify app to read/query from `date_of_birth_plaintext`, add `date_of_birth` to `User.ignored_columns`
>   7. Deploy
>   8. `drop_column :users, :date_of_birth`
> 2. Create the encrypted column:
>   1. `create_column :users, :date_of_birth, :enquo_date`
>   2. Modify the model to write changes to `date_of_birth_plaintext` to `date_of_birth` as well, remove `date_of_birth` from `User.ignored_columns`
>   3. Deploy
>   4. Migration to encrypt all `date_of_birth_plaintext` values into `date_of_birth`
>   5. Deploy
>   6. Modify app to read/encrypted query from `date_of_birth`, add `date_of_birth_plaintext` to `User.ignored_columns`
>   7. Deploy
>   8. `drop_column :users, :date_of_birth_plaintext`
