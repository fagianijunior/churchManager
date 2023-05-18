# lib/tasks/s3_to_local.rake 
desc "Sync files from S3 bucket to local storage folder"

task :s3_to_local do

  s3_bucket = "ibrmaranata-media-production"
  access_key_id = Rails.application.credentials.dig(:aws, :access_key_id)
  secret_access_key = Rails.application.credentials.dig(:aws, :secret_access_key)

  storage_folder = Rails.root.join('storage')
  storage_folder.mkpath

  system("AWS_ACCESS_KEY_ID=#{access_key_id} AWS_SECRET_ACCESS_KEY=#{secret_access_key} aws s3 sync s3://#{s3_bucket} #{storage_folder}")

  # Ignores sub_folders already created and .keep files
  images = storage_folder.children.select { |file| file.file? && !file.empty? }

  # Formats the file path of each image so ActiveStorage understands them using :local storage
  images.each do |path_name|
    dir, basename = path_name.split
    file_name = basename.to_s
    sub_folders = dir.join(file_name[0..1], file_name[2..3])
    sub_folders.mkpath # Create the subfolder used by active_record
    path_name.rename(dir + sub_folders + basename) # Renames file to be moved into subfolder
  end

end
