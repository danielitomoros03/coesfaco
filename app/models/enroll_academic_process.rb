class EnrollAcademicProcess < ApplicationRecord
  # SCHEMA:
  # t.bigint "grade_id", null: false
  # t.bigint "academic_process_id", null: false
  # t.integer "enroll_status"
  # t.integer "permanence_status"

  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # ASSOCIATIONS:
  belongs_to :grade
  has_one :student, through: :grade
  has_one :user, through: :student
  has_one :school, through: :grade
  
  belongs_to :academic_process
  has_one :period, through: :academic_process
  has_many :payment_reports, as: :payable
  has_many :academic_records, dependent: :destroy
  has_many :sections, through: :academic_records
  has_many :subjects, through: :sections

  # ENUMERIZE:
  # IDEA CON ESTADO DE INSCRIPCIÓN EN GRADE Y ENROLL ACADEMIC PROCESS
  enum enroll_status: [:preinscrito, :reservado, :confirmado, :retirado]
  enum permanence_status: [:nuevo, :regular, :reincorporado, :articulo3, :articulo6, :articulo7, :intercambio, :desertor, :egresado, :egresado_doble_titulo]  

  # VALIDATIONS:
  validates :grade, presence: true
  validates :academic_process, presence: true
  validates :enroll_status, presence: true

  validates_uniqueness_of :academic_process, scope: [:grade], message: 'Ya inscrito en período', field_name: false
  # validates :permanence_status, presence: true

  # SCOPE:
  scope :todos, -> {where('0 = 0')}

  scope :of_academic_process, -> (academic_process_id) {where(academic_process_id: academic_process_id)}

  scope :sort_by_period, -> {joins(period: :period_type).order('periods.year': :desc, 'period_types.name': :desc)}

  scope :without_academic_records, -> {joins(:academic_records).group(:"enroll_academic_processes.id").having('COUNT(*) = 0').count}

  scope :with_any_academic_records, -> {joins(:academic_records).group(:"enroll_academic_processes.id").having('COUNT(*) > 0').count}

  scope :with_i_academic_records, -> (i){joins(:academic_records).group(:"enroll_academic_processes.id").having('COUNT(*) = ?', i).count}
  
  scope :total_with_i_academic_records, -> (i){(joins(:academic_records).group(:"enroll_academic_processes.id").having('COUNT(*) = ?', i).count).count}

  scope :custom_search, -> (keyword) { joins(:user, :period).where("users.ci ILIKE '%#{keyword}%' OR periods.name ILIKE '%#{keyword}%'") }

  # FUNCTIONS:
  def any_permanence_articulo?
    (self.articulo3? or self.articulo6? or self.articulo7?)
  end

  def set_default_values_by_import
    self.enroll_status = :confirmado
    self.permanence_status = :regular
  end

  def enrolling?
    school.enroll_process_id.eql? academic_process_id  
  end

  def total_academic_records
    self.subjects.count
  end

  def total_subjects
    subjects.count
  end

  def total_credits
    subjects.sum(:unit_credits)
  end

  def short_name
    "#{self.school.code}_#{self.period.name_revert}_#{self.student.user_ci}"
  end

  def name
    "(#{self.school.code}) #{self.period.name}:#{self.student.name}" if ( self.period and self.school and self.student)
  end

  def label_status
    # ["CO", "INS", "NUEVO", "PRE", "REINC", "RES", "RET", "VAL"] 
    case self.enroll_status
    when 'confirmado'
      label_color = 'success'
    when 'preinscrito'
      label_color = 'info'
    when 'retirado'
      label_color = 'danger'
    else
      label_color = 'secondary'
    end
    return ApplicationController.helpers.label_status("bg-#{label_color}", self.enroll_status.titleize)

  end  

  rails_admin do
    navigation_label 'Gestión Periódica'
    navigation_icon 'fa-solid fa-calendar-check'
    weight 0
    
    show do
      field :enrolling do
        label "INSCRIPCIÓN"
        formatted_value do
          current_user = bindings[:view]._current_user

          admin = current_user.admin

          if admin and admin.authorized_manage? 'EnrollAcademicProcess'
            grade = bindings[:object].grade
            # school = grade.school
            if academic_process = bindings[:object].academic_process
              enroll_in_process = grade.enroll_academic_processes.where(academic_process_id: academic_process.id).first

              totalCreditsReserved = enroll_in_process ? enroll_in_process.total_credits : 0
              totalSubjectsReserved = enroll_in_process ? enroll_in_process.total_subjects : 0

              bindings[:view].render(partial: '/enroll_academic_processes/form', locals: {grade: grade, academic_process: academic_process, totalCreditsReserved: totalCreditsReserved, totalSubjectsReserved: totalSubjectsReserved})
            end
          else
            'Acceso restringido'
          end
        end
      end      
    end

    edit do
      fields :grade, :academic_process, :enroll_status, :permanence_status
    end

    list do
      search_by :custom_search
      # filters [:period_name, :student]
      scopes [:todos, :preinscrito, :reservado, :confirmado, :retirado]

      field :enroll_status_label do
        label 'Estado'
        column_width 100
        searchable 'enroll_status'
        filterable 'enroll_status'
        sortable 'enroll_status'
        formatted_value do
          bindings[:object].label_status
        end        
      end

      field :period_name do
        label 'Período'
        column_width 100
        # searchable 'periods.name'
        # filterable 'periods.name'
        # sortable 'periods.name'
        formatted_value do
          bindings[:object].period.name if bindings[:object].period
        end        
      end

      field :student do
        column_width 340
        # searchable ['users.ci', 'users.first_name', 'users.last_name']
        # filterable ['users.ci', 'users.first_name', 'users.last_name']
        # sortable ['users.ci', 'users.first_name', 'users.last_name']
      end
      field :total_subjects do
        label 'Tot Asig'
        column_width 40
      end

      field :total_credits do
        label 'Tot Cred'
        column_width 40
      end

      field :created_at do
        label 'Fecha de Inscripción'
      end
    end

    export do
      fields :enroll_status, :permanence_status, :grade, :period, :student, :user
    end
  end


  private


    def paper_trail_update
      changed_fields = self.changes#.keys - ['created_at', 'updated_at']
      changed_fields = changed_fields.map do |fi|
        if fi[0] != 'updated_at'
          elem = I18n.t("activerecord.attributes.#{self.model_name.param_key}.#{fi[0]}").to_s
          elem += " de #{fi[1][0]} a #{fi[1][1]}"
        end
      end
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} actualizada en: #{changed_fields.to_sentence}"
    end  
    def paper_trail_create
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} registrado!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡Proceso Académico eliminado!"
    end


end
