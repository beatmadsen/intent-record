class CreateInitialSchema < ActiveRecord::Migration[8.0]
  def change
    create_table :vcs_systems do |t|
      t.string :name, null: false
      t.datetime :created_at, null: false
    end
    add_index :vcs_systems, :name, unique: true

    create_table :asset_versions do |t|
      t.references :vcs_system, null: false, foreign_key: true
      t.string :external_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :asset_versions, %i[vcs_system_id external_id], unique: true
    add_index :asset_versions, :external_id

    create_table :intent_records do |t|
      t.string :global_id, limit: 7, null: false
      t.string :summary, null: false
      t.text :body, null: false
      t.string :author
      t.datetime :created_at, null: false
    end
    add_index :intent_records, :global_id, unique: true
    add_index :intent_records, :created_at

    create_table :intent_record_asset_versions do |t|
      t.references :intent_record, null: false, foreign_key: true
      t.references :asset_version, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
    add_index :intent_record_asset_versions, %i[intent_record_id asset_version_id],
              unique: true, name: "idx_intent_asset_unique"

    create_table :stakeholder_systems do |t|
      t.string :name, null: false
      t.datetime :created_at, null: false
    end
    add_index :stakeholder_systems, :name, unique: true

    create_table :stakeholder_sources do |t|
      t.references :stakeholder_system, null: false, foreign_key: true
      t.text :uri, null: false
      t.string :title
      t.datetime :created_at, null: false
    end
    add_index :stakeholder_sources, %i[stakeholder_system_id uri], unique: true

    create_table :stakeholder_references do |t|
      t.references :intent_record, null: false, foreign_key: true
      t.references :stakeholder_source, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
    add_index :stakeholder_references, %i[intent_record_id stakeholder_source_id],
              unique: true, name: "idx_stakeholder_ref_unique"

    create_table :intent_record_links do |t|
      t.bigint :source_intent_record_id, null: false
      t.bigint :target_intent_record_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :intent_record_links, %i[source_intent_record_id target_intent_record_id],
              unique: true, name: "idx_intent_link_unique"
    add_index :intent_record_links, :target_intent_record_id
    add_foreign_key :intent_record_links, :intent_records, column: :source_intent_record_id
    add_foreign_key :intent_record_links, :intent_records, column: :target_intent_record_id
  end
end
