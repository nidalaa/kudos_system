class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees do |t|
      t.string :first_name, null: false
      t.string :last_name                # no null: false — last_name is optional for mononyms
      t.string :username,   null: false

      t.timestamps
    end

    add_index :employees, :username, unique: true
  end
end
