class CreateKudos < ActiveRecord::Migration[8.0]
  def change
    create_table :kudos do |t|
      t.references :giver,    null: false, foreign_key: { to_table: :employees }
      t.references :receiver, null: false, foreign_key: { to_table: :employees }
      t.string  :reactions_from, array: true, default: []
      t.text    :reason
      t.string  :category
      t.text    :original_message
      t.string  :slack_message_id, null: false
      t.string  :slack_channel
      t.datetime :slack_timestamp
      t.string  :status, null: false, default: "pending_review"

      t.timestamps
    end

    add_index :kudos, :slack_message_id, unique: true
    add_index :kudos, :status
  end
end
