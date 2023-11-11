# frozen_string_literal: true

class PreviewDocumentPageController < ActionController::API
  include ActiveStorage::SetCurrent

  FORMAT = Templates::ProcessDocument::FORMAT

  def show
    attachment = ActiveStorage::Attachment.find_by(uuid: params[:attachment_uuid])

    return head :not_found unless attachment

    preview_image = attachment.preview_images.joins(:blob).find_by(blob: { filename: "#{params[:id]}#{FORMAT}" })

    return redirect_to preview_image.url, allow_other_host: true if preview_image

    file_path =
      if attachment.service.name == :disk
        ActiveStorage::Blob.service.path_for(attachment.key)
      else
        find_or_create_document_tempfile_path(attachment)
      end

    io = Templates::ProcessDocument.generate_pdf_preview_from_file(attachment, file_path, params[:id].to_i)

    render plain: io.tap(&:rewind).read, content_type: 'image/jpeg'
  end

  def find_or_create_document_tempfile_path(attachment)
    file_path = "#{Dir.tmpdir}/#{attachment.uuid}"

    File.open(file_path, File::RDWR | File::CREAT, 0o644) do |f|
      f.flock(File::LOCK_EX)

      # rubocop:disable Style/ZeroLengthPredicate
      if f.size.zero?
        f.binmode

        f.write(attachment.download)
      end
      # rubocop:enable Style/ZeroLengthPredicate
    end

    file_path
  end
end
