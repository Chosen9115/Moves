class BackupsController < ApplicationController
  def export
    payload = BackupExporter.call
    filename = "moves-backup-#{Time.current.strftime('%Y%m%d-%H%M%S')}.json"
    send_data JSON.pretty_generate(payload), filename: filename, type: "application/json"
  end

  def import
    file = params[:backup_file]

    if file.blank?
      redirect_to settings_path, alert: "Select a backup file first."
      return
    end

    BackupImporter.call(file.read)
    redirect_to settings_path, notice: "Backup imported successfully."
  rescue BackupImporter::ImportError => e
    redirect_to settings_path, alert: e.message
  rescue StandardError => e
    redirect_to settings_path, alert: "Import failed: #{e.message}"
  end
end
