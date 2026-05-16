class ChangeKudosUniqueIndexToMessageAndReceiver < ActiveRecord::Migration[8.0]
  def change
    remove_index :kudos, :slack_message_id, unique: true
    add_index :kudos, [:slack_message_id, :receiver_id], unique: true, name: "index_kudos_on_message_and_receiver"
  end
end
