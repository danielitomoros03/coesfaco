class AcademicProcess < ApplicationRecord
  # SCHEMA:
    # t.bigint "school_id", null: false
    # t.bigint "period_id", null: false
    # t.integer "max_credits"
    # t.integer "max_subjects"
    # t.integer "modality"

  # ASSOCIATIONS:
  #belongs_to:
  belongs_to :school
  belongs_to :period
  has_one :period_type, through: :period

  #has_many:
  has_many :enroll_academic_processes, dependent: :destroy
  has_many :grades, through: :enroll_academic_processes
  has_many :students, through: :grades
  has_many :courses
  has_many :subjects, through: :courses

  # ENUMERIZE:
  enum modality: [:semestral, :anual]

  #VALIDATIONS:
  validates :school, presence: true
  validates :period, presence: true
  validates :modality, presence: true
  validates :max_credits, presence: true
  validates :max_subjects, presence: true

  def name
    "#{self.school.code} | #{self.period.name}" if self.school and self.period
  end

  def total_enroll_academic_processes
    self.enroll_academic_processes.count
  end

  rails_admin do
    navigation_label 'Inscripciones'
    navigation_icon 'fa-solid fa-calendar'
    list do
      fields :period, :school
      field :total_enroll_academic_processes do
        label 'Total Inscritos'
      end
    end

    edit do
      fields :school, :period, :modality, :subjects, :max_credits, :max_subjects
    end

    export do
      fields :school, :period, :period_type, :modality, :max_credits, :max_subjects
    end
  end

  after_initialize do
    if new_record?
      self.school_id ||= School.first.id
    end
  end

end
