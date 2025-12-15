class AddNameToSolidQueueProcesses < ActiveRecord::Migration[8.1]
  def change
    add_column :solid_queue_processes, :name, :string
  end
end
