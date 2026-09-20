# A relevance index over the text of an intent record. It decides the order the
# search answers in, never which records the search answers with: FTS5 tokenises,
# so it cannot see a substring inside a word and it cannot tell `100%` from `100
# percent`, both of which the substring search is asked for and tested on.
#
# Kept in step by triggers rather than from Ruby, so a writer that never heard of
# the index cannot leave it stale. `backfill` writes through `record` today, but
# the guarantee should not depend on that staying true.
class CreateSearchIndex < ActiveRecord::Migration[8.0]
  TABLE = "intent_search".freeze
  SOURCE = "intent_records".freeze

  def up
    # An external-content table: the text lives in intent_records and the index
    # stores only the terms, so the store does not carry a second copy of every
    # body.
    execute(<<~SQL)
      CREATE VIRTUAL TABLE #{TABLE} USING fts5(
        summary, body,
        content='#{SOURCE}', content_rowid='id',
        tokenize='porter unicode61'
      )
    SQL

    create_triggers
    backfill_existing
  end

  def down
    %w[insert update delete].each { |event| execute("DROP TRIGGER IF EXISTS #{TABLE}_after_#{event}") }
    execute("DROP TABLE IF EXISTS #{TABLE}")
  end

  private

  # An external-content table is told about a change rather than reading it: the
  # 'delete' command hands back the old text so FTS5 can retract the terms it
  # indexed, which is why an update deletes before it inserts.
  def create_triggers
    execute(<<~SQL)
      CREATE TRIGGER #{TABLE}_after_insert AFTER INSERT ON #{SOURCE} BEGIN
        INSERT INTO #{TABLE}(rowid, summary, body) VALUES (new.id, new.summary, new.body);
      END
    SQL
    execute(<<~SQL)
      CREATE TRIGGER #{TABLE}_after_delete AFTER DELETE ON #{SOURCE} BEGIN
        INSERT INTO #{TABLE}(#{TABLE}, rowid, summary, body) VALUES('delete', old.id, old.summary, old.body);
      END
    SQL
    execute(<<~SQL)
      CREATE TRIGGER #{TABLE}_after_update AFTER UPDATE ON #{SOURCE} BEGIN
        INSERT INTO #{TABLE}(#{TABLE}, rowid, summary, body) VALUES('delete', old.id, old.summary, old.body);
        INSERT INTO #{TABLE}(rowid, summary, body) VALUES (new.id, new.summary, new.body);
      END
    SQL
  end

  # A store that already holds records gets them indexed here, so ranking works
  # on the history from the first run after the upgrade rather than only on what
  # is written afterwards.
  def backfill_existing
    execute("INSERT INTO #{TABLE}(rowid, summary, body) SELECT id, summary, body FROM #{SOURCE}")
  end
end
