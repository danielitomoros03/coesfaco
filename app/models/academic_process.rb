class AcademicProcess < ApplicationRecord
  # SCHEMA:
    # t.bigint "school_id", null: false
    # t.bigint "period_id", null: false
    # t.integer "max_credits"
    # t.integer "max_subjects"
    # t.integer "modality"
    # t.bigint "process_before_id"

  # ASSOCIATIONS:
  #belongs_to:
  belongs_to :school
  belongs_to :period
  has_one :period_type, through: :period

  belongs_to :process_before, class_name: 'AcademicProcess', optional: true

  #has_many:
  has_many :enrollment_days, dependent: :destroy
  has_many :enroll_academic_processes, dependent: :destroy
  has_many :grades, through: :enroll_academic_processes
  has_many :students, through: :grades
  has_many :courses
  has_many :sections, through: :courses
  has_many :subjects, through: :courses

  # ENUMERIZE:
  enum modality: [:Semestral, :Anual]

  #VALIDATIONS:
  validates :school, presence: true
  validates :period, presence: true
  validates :modality, presence: true
  validates :max_credits, presence: true
  validates :max_subjects, presence: true

  validates_uniqueness_of :school, scope: [:period], message: 'Proceso academico ya creado', field_name: false

  def default_value_by_import
    max_credits = 24
    max_subject = 5
    modality = :semestral
  end

  def name
    "#{self.school.code} | #{self.period.name}" if (self.school and self.period)
  end

  def total_enroll_academic_processes
    self.enroll_academic_processes.count
  end

  def label_total_enrolls_by_status
    total = []
    EnrollAcademicProcess.enroll_statuses.map do |k,v|
      total_aux = self.enroll_academic_processes.where(enroll_status: v).count 
      value = v
      total << ApplicationController.helpers.label_status_with_tooptip('bg-secondary', total_aux, k.titleize)
    end
    return total
  end

  def label_total_sections
    total = []
    total << ApplicationController.helpers.label_status_with_tooptip('bg-info', total_sections, 'Total')
    total << ApplicationController.helpers.label_status_with_tooptip('bg-success', total_sections_qualified, 'Calificadas')
    
    total << ApplicationController.helpers.label_status_with_tooptip('bg-danger', total_sections_without_teacher_assigned, 'Sin Profesor Asignado')

    return total
  end

  def total_sections
    self.sections.count
  end

  def total_sections_qualified
    self.sections.qualified.count
  end

  def total_sections_without_teacher_assigned
    self.sections.without_teacher_assigned.count
  end

  def readys_to_enrollment_day
    self.school.grades.without_appointment_time.enrolled_in_academic_process(self.process_before.id).sort_by_numbers.uniq if process_before
  end

  rails_admin do
    navigation_label 'Inscripciones'
    navigation_icon 'fa-solid fa-calendar'
    weight -2
    list do
      fields :period do
        column_width 100
        pretty_value do
          value.name
        end
      end

      fields :school do
        column_width 600
        pretty_value do
          value.name
        end
      end
      field :process_before do
        column_width 100
        pretty_value do
          value.name if value
        end
      end

      field :total_sections do
        column_width 100
        label 'Total Sec.'
        pretty_value do
          %{<span class='badge bg-info'>#{value}</span>}.html_safe
        end
      end

      field :total_enroll_academic_processes do
        column_width 200
        label 'Total Inscritos'
        pretty_value do
          %{<span class='badge bg-info'>#{value}</span>}.html_safe
        end
      end
    end

    edit do
      field :period
      field :school do
        inline_edit false
        inline_add false
      end
      field :modality
      field :process_before do
        help 'Atención: Aún cuando este campo no es obligatorio y puede ser omitido (en caso de que se encuentre realizando migraciones de periodos anteriores) es muy importante para las Citas Horarias e Inscripciones'
      end

      field :max_credits do
        label 'Máximo de créditos permitidos a inscribir'
      end
      field :max_subjects do
        label 'Máximo de asignaturas permitidas a inscribir'
      end
    end

    show do
      field :name do
        label 'Descripción'
        pretty_value do
          bindings[:view].render(partial: "/academic_processes/desc_table", locals: {academic_process: bindings[:object]})
        end
      end

      field :courses do
        label 'Opciones de Oferta Docente'
        pretty_value do
          bindings[:view].render(partial: "/academic_processes/clonation_options", locals: {academic_process: bindings[:object]})
        end
      end

      field :enrollment_days do
        pretty_value do

          if bindings[:object].process_before
            enrollment_days = bindings[:object].enrollment_days
            grades_without_appointment = bindings[:object].readys_to_enrollment_day

            bindings[:view].render(partial: "/enrollment_days/index", locals: {enrollment_days: enrollment_days, grades_without_appointment: grades_without_appointment, academic_process: bindings[:object]})

          else
            bindings[:view].content_tag(:p, 'Sin proceso academico anterio vinculado. Para habilitar el sistema de Cita Horaria en este proceso académico, por favor edítelo y agregue un proceso anteriór', {class: 'alert alert-warning'})
        
            
          end
        end

      end
    end

    export do
      fields :school, :period, :modality, :subjects, :max_credits, :max_subjects
    end
  end

  after_initialize do
    if new_record?
      self.school_id ||= School.first.id
    end
  end

end
