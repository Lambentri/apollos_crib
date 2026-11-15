defmodule RoomSanctum.Repo.Migrations.UsersHashedPasswordNullable do
  use Ecto.Migration

  # "Sign in with NEIAM" (neiam_auth) can create an account with no password
  # (OIDC_PROVISION=auto). gen.auth 1.7 made the column NOT NULL; 1.8 drops
  # that, and User.valid_password?/2 already refuses a nil hash.
  #
  # Down puts NOT NULL back, which fails while any passwordless row exists:
  # give those users a password, or delete them, first.
  def change do
    alter table(:users) do
      modify :hashed_password, :string, null: true, from: {:string, null: false}
    end
  end
end
