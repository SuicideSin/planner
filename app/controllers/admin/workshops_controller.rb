class Admin::WorkshopsController < Admin::ApplicationController
  include  Admin::SponsorConcerns
  include  Admin::WorkshopConcerns

  before_filter :set_workshop_by_id, only: [:show, :edit]
  before_filter :set_and_decorate_workshop, only: [:coaches_checklist, :students_checklist]

  def index
    @chapter = Chapter.find(params[:chapter_id])
    authorize @chapter
  end

  def new
    @workshop = Sessions.new
    authorize @workshop
  end

  def create
    @workshop = Sessions.new(workshop_params)
    authorize(@workshop)

    if @workshop.save
      set_host(host_id)

      redirect_to admin_workshop_path(@workshop), notice: "The workshop has been created."
    else
      flash[:notice] = @workshop.errors.full_messages
      render 'new'
    end
  end

  def edit
    authorize @workshop
  end

  def show
    authorize @workshop

    @address = AddressDecorator.decorate(@workshop.host.address) if @workshop.has_host?
    return render text: WorkshopPresenter.new(@workshop).attendees_csv if request.format.csv?

    set_admin_workshop_data
  end

  def update
    @workshop = Sessions.find(params[:id])
    authorize @workshop

    @workshop.update_attributes(workshop_params)

    if organiser_ids
      organiser_ids.reject(&:empty?).each { |oid| Member.find(oid).add_role(:organiser, @workshop) }
    end

    set_host(host_id)

    redirect_to admin_workshop_path(@workshop), notice: "Workshops updated succesfully"
  end

  def coaches_checklist
    return render text: @workshop.coaches_checklist if request.format.text?

    redirect_to admin_workshop_path(@workshop)
  end

  def students_checklist
    return render text: @workshop.students_checklist if request.format.text?

    redirect_to admin_workshop_path(@workshop)
  end

  def invite
    set_workshop
    authorize @workshop

    InvitationManager.send_session_emails(@workshop)

    redirect_to admin_workshop_path(@workshop), notice: "Invitations sent!"
  end

  private

  def workshop_params
    params.require(:sessions).permit(:date_and_time, :time, :chapter_id, :invitable, :seats, sponsor_ids: [])
  end

  def sponsor_id
    workshop_params[:sponsor_ids][1]
  end

  def set_workshop_by_id
    @workshop = Sessions.find(params[:id])
  end

  def set_and_decorate_workshop
    workshop = Sessions.find(params[:workshop_id])
    @workshop = WorkshopPresenter.new(workshop)
  end

  def workshop_id
    params[:workshop_id] || params[:id]
  end

  private

  def set_host(host_id)
    return unless host_id

    host = @workshop.sponsor_sessions.find_or_initialize_by(sponsor_id: host_id)
    unless @workshop.host.eql?(host.sponsor)
      @workshop.sponsor_sessions.where(sponsor: @workshop.host).delete_all
      host.update(host: true)
    end
  end

  def host_id
    params[:sessions][:host]
  end

  def organiser_ids
    params[:sessions][:organisers]
  end
end
