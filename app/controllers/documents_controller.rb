class DocumentsController < ApplicationController
  default_search_scope :documents
  model_object Document
  before_filter :find_project_by_project_id, :only => [:index, :new, :create]
  before_filter :find_model_object, :except => [:index, :new, :create]
  before_filter :find_project_from_association, :except => [:index, :new, :create]
  before_filter :authorize

  helper :attachments

  def index
    @sort_by = %w(category date title author).include?(params[:sort_by]) ? params[:sort_by] : 'category'
    documents = @project.documents.includes(:attachments, :category).all
    case @sort_by
    when 'date'
      @grouped = documents.group_by {|d| d.updated_on.to_date }
    when 'title'
      @grouped = documents.group_by {|d| d.title.first.upcase}
    when 'author'
      @grouped = documents.select{|d| d.attachments.any?}.group_by {|d| d.attachments.last.author}
    else
      @grouped = documents.group_by(&:category)
    end
    @document = @project.documents.build
    nullify_project_constants
    Document::DOC_PROJECT.replace @document.project.name
    render :layout => false if request.xhr?
  end

  def show
    @attachments = @document.attachments.all
  end

  def new
    @document = @project.documents.build
    @document.safe_attributes = params[:document]
  end

  def create
    @document = @project.documents.build
    @document.safe_attributes = params[:document]
    @document.save_attachments(params[:attachments])
    if @document.save
      render_attachment_warning_if_needed(@document)
      flash[:notice] = l(:notice_successful_create)
      redirect_to project_documents_path(@project)
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    @document.safe_attributes = params[:document]
    if request.put? and @document.save
      flash[:notice] = l(:notice_successful_update)
      redirect_to document_path(@document)
    else
      render :action => 'edit'
    end
  end

  def destroy
    @document.destroy if request.delete?
    redirect_to project_documents_path(@project)
  end

  def add_attachment
    attachments = Attachment.attach_files(@document, params[:attachments])
    render_attachment_warning_if_needed(@document)

    if attachments.present? && attachments[:files].present? && Setting.notified_events.include?('document_added')
      Mailer.attachments_added(attachments[:files]).deliver
    end
    redirect_to document_path(@document)
  end
end
