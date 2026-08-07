defmodule RoomSanctum.Repo.Migrations.AddImapToCfgMailboxes do
  use Ecto.Migration

  def change do
    alter table(:cfg_mailboxes) do
      # Credentials for pulling mail instead of having it pushed at our SMTP
      # listener. Null host means this mailbox is SMTP-delivered.
      add :imap_host, :string
      add :imap_port, :integer, default: 993
      add :imap_username, :string
      add :imap_password, :string
      add :imap_tls, :boolean, default: true, null: false
      add :imap_folder, :string, default: "INBOX"

      # Bookkeeping so the UI can show whether polling is actually working
      # without digging through logs.
      add :imap_last_polled_at, :utc_datetime
      add :imap_last_error, :string
    end

    create index(:cfg_mailboxes, [:imap_host])
  end
end
