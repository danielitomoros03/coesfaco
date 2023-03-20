RailsAdmin.config do |config|
  config.asset_source = :webpack

  ### Popular gems integration
  config.main_app_name = Proc.new { |controller| [ "Coes", "FAU - #{I18n.t(controller.params[:action]).try(:titleize)}" ] }

  ## == Devise ==
  config.authenticate_with do
    warden.authenticate! scope: :user
  end
  config.current_user_method(&:current_user)

  ## == CancanCan ==
  config.authorize_with :cancancan

  ## == Pundit ==
  # config.authorize_with :pundit

  ## == PaperTrail ==
  config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/railsadminteam/rails_admin/wiki/Base-configuration

  ## == Gravatar integration ==
  ## To disable Gravatar integration in Navigation Bar set to false
  config.show_gravatar = false

  # config.show_gravatar do |config|
  #   config.gravatar_url do
  #     current_user.profile_picture
  #   end
  # end

  # IMPORTER:

  config.configure_with(:import) do |config|
    config.logging = false
    config.line_item_limit = 3000
    config.update_if_exists = true
    config.rollback_on_error = false
  end


  config.actions do
    dashboard                     # mandatory
    index do                         # mandatory

      except [SectionTeacher, Profile, Address, EnrollmentDay, Qualification, Dependency]
      # except [Address, SectionTeacher, Profile, User, StudyPlan, Period, Course, Faculty]

    end
    new do
      except [School, Faculty]
    end
    export do
      except [School]

    end
    bulk_delete
    show
    edit
    delete do
      except [School, StudyPlan, Faculty, Subject]
    end
    import do
      only [User, Student, Teacher, Subject, Section, AcademicRecord]
    end
    # show_in_app

    ## With an audit adapter, you can add:
    history_index do
      only [User, Admin, Student, Teacher]
    end

    # history_show do
    #   only [User, Admin, Student, Teacher]
    # end
  end



  # config.model "ActionText::RichText" do
  #   visible false
  # end

  # config.model 'User' do
  #   configure :preview do
  #     children_fields [:name, :last_name, :email, :ci]
  #   end
  # end

  config.model "ActiveStorage::Blob" do
    visible false
  end
  config.model "ActiveStorage::Attachment" do
    visible false
  end
  config.model "ActiveStorage::VariantRecord" do
    visible false
  end
end
