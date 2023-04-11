class Section < ApplicationRecord
  # SCHEMA:
  # t.string "code"
  # t.integer "capacity"
  # t.bigint "course_id", null: false
  # t.bigint "teacher_id", null: false
  # t.boolean "qualified"
  # t.integer "modality"
  # t.boolean "enabled"

  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # ASSOCIATIONS:
  # belongs_to
  belongs_to :course
  belongs_to :teacher, optional: true
  has_one :user, through: :teacher

  # has_one
  has_one :subject, through: :course
  # accepts_nested_attributes_for :subject

  has_one :academic_process, through: :course
  # accepts_nested_attributes_for :academic_process

  has_one :period, through: :academic_process
  has_one :school, through: :academic_process
  has_one :faculty, through: :school

  # has_many
  has_many :schedules, dependent: :destroy
  accepts_nested_attributes_for :schedules, allow_destroy: true

  has_many :academic_records, dependent: :destroy
  # accepts_nested_attributes_for :academic_records

  has_many :enroll_academic_processes, through: :academic_records
  has_many :grades, through: :enroll_academic_processes
  has_many :students, through: :grades

  # has_and_belongs_to_namy
  # has_and_belongs_to_many :secondary_teachers, class_name: 'SectionTeacher'

  #ENUMERIZE:
  enum modality: [:nota_final, :equivalencia_interna]

  # VALIDATIONS:

  validates :code, presence: true, uniqueness: { scope: :course_id, message: 'Ya existe la sesión para el curso', case_sensitive: false, field_name: false}, length: { in: 1..4, too_long: "%{count} caracteres es el máximo permitido", too_short: "%{count} caracter es el mínimo permitido"}
  validates :capacity, presence: true
  validates :course, presence: true
  validates :modality, presence: true

  # validates_uniqueness_of :code, scope: [:course_id], message: 'La oferta docente ya existe!', field_name: false


  # SCOPE:
  # default_scope {joins(:period, :subject)}

  scope :custom_search, -> (keyword) { joins(:user, :period, :subject).where("subjects.name ILIKE '%#{keyword}%' OR subjects.code ILIKE '%#{keyword}%' OR periods.name ILIKE '%#{keyword}%' OR users.ci ILIKE '%#{keyword}%'") }
  scope :qualified, -> () {where(qualified: true)}

  scope :without_teacher_assigned, -> () {where(teacher_id: nil)}
  scope :with_teacher_assigned, -> () {where('teacher_id IN NOT NULL')}

  scope :has_capacity, -> {joins(:academic_records).group('sections.id').having('count(academic_records.id) < sections.capacity').order('count(academic_records.id)')}

  scope :has_academic_record, -> (academic_record_id) {joins(:academic_records).where('academic_records.id': academic_record_id)}

  # FUNCTIONS:
  def total_students
    self.academic_records.count
  end

  def excel_list
    require 'spreadsheet'

    @book = Spreadsheet::Workbook.new
    @sheet = @book.create_worksheet :name => "Seccion #{self.name}"


    enrolls = self.academic_records.not_retirado.sort_by_user_name


    @sheet.column(0).width = 15 #estudiantes.collect{|e| e.cal_usuario_ci.length if e.cal_usuario_ci}.max+2;
    @sheet.column(1).width = 50 #estudiantes.collect{|e| e.cal_usuario.apellido_nombre.length if e.cal_usuario.apellido_nombre}.max+2;
    @sheet.column(2).width = 15 #estudiantes.collect{|e| e.cal_usuario.correo_electronico.length if e.cal_usuario.correo_electronico}.max+2;
    @sheet.column(3).width = 40
    @sheet.column(4).width = 20

    @sheet.row(0).concat ["Profesor: #{self.teacher_desc}"]
    @sheet.row(1).concat ["Sección: #{self.name}"]
    @sheet.row(3).concat %w{CI NOMBRES ESTADO CORREO TELÉFONO}

    data = []
    enrolls.each_with_index do |e,i|
      usuario = e.user
      @sheet.row(i+4).concat e.data_to_excel
    end

    file_name = "reporte_seccion_temp"
    return file_name if (@book.write file_name)
  end



  # def own_grades_to_csv

  #   CSV.generate do |csv|
  #     csv << ['Cédula', 'Apellido y Nombre', 'desde', 'hasta', 'Efficiencia', 'Promedio', 'Ponderado']
  #     own_grades_sort_by_appointment.each do |grade|
  #       user = grade.user
  #       csv << [user.ci, user.reverse_name, grade.appointment_from, grade.appointment_to, grade.efficiency, grade.simple_average, grade.weighted_average]
  #     end
  #   end
  # end


  def capacity_vs_enrolls
    # "#{self.capacity} / #{self.total_students}"
    "#{self.total_students} de #{self.capacity}"
  end

  def description_with_quotes
    aux = "[#{self.teacher.user.short_name}]" if self.teacher
    schedule = "#{self.schedule_short_name}" if self.schedules
    "#{code} #{aux} - #{schedule} (#{capacity_vs_enrolls})"
  end

  def has_academic_record? academic_record_id
    self.academic_records.where(id: academic_record_id).any?
  end

  def has_capacity?
    self.capacity and (self.capacity > 0) and (self.total_students < self.capacity)
  end

  def set_default_values_by_import
    self.capacity = 50 
    self.modality =  (self.code.eql? 'U') ? :equivalencia_interna : :nota_final
  end

  def totaly_qualified?
    !academic_records.sin_calificar.any?
  end

  def qualified?
    qualified.eql? true    
  end

  def teacher_desc
    teacher ? teacher.description : 'No Asignado'
  end

  def conv_long
    "U#{self.period.period_type.code}"
  end

  def conv_type
    "#{conv_initial_type}S#{self.period.period_type.code.upcase}"
  end

  def conv_initial_type
    case modality
    when 'nota_final'
      'NF'
    when 'equivalencia_interna'
      'EQ'
    else
      modality.first.upcase if modality
    end
  end


  def number_acta
    "#{self.subject.code.upcase}#{self.code.upcase} #{self.period.name_revert}"
  end

  def name_to_file
     "#{self.period.name}_#{self.subject.code.upcase}_#{self.code.upcase}" if self.course
  end

  def name
     "#{self.course.name}-#{self.description_with_quotes}" if self.course
  end

  def desc_subj_code
    "#{subject.desc} (#{self.code})"
  end

  def total_academic_records
    academic_records.count
  end

  def subject_desc
    subject.desc if subject
  end

  def period_name
    period.name if period
  end

  def schedule_name
    schedules.map{|s| s.name}.to_sentence
  end

  def schedule_short_name
    schedules.map{|s| s.short_name}.to_sentence    
  end

  def teacher_desc 
    teacher.user.ci_fullname if (teacher and teacher.user)
  end

  def schedule_table
    schedules.each{|s| s.name}.to_sentence
  end
  # RAILS_ADMIN:
  rails_admin do
    navigation_label 'Inscripciones'
    navigation_icon 'fa-solid fa-list'
    weight -1

    list do
      search_by :custom_search
      # filters [:period_name, :code, :subject_code]
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

      field :code do
        label 'Sec'
        column_width 30
        formatted_value do
          bindings[:view].link_to(bindings[:object].code, "/admin/section/#{bindings[:object].id}") if bindings[:object].present?

        end
      end

      field :subject_code do
        label 'Asignatura'
        column_width 240
        # searchable 'subjects.code'
        # filterable 'subjects.code'
        # sortable 'subjects.code'
        formatted_value do
          bindings[:view].link_to(bindings[:object].subject.desc, "/admin/subject/#{bindings[:object].subject.id}") if bindings[:object].subject.present?

        end
      end

      field :teacher_desc do
        label 'Profesor'
        column_width 240
        # searchable ['users.ci', 'users.first_name', 'users.last_name']
        # filterable ['users.ci', 'users.first_name', 'users.last_name']
        # sortable ['users.ci', 'users.first_name', 'users.last_name']
        formatted_value do
          bindings[:view].link_to(bindings[:object].teacher.desc, "/admin/teacher/#{bindings[:object].teacher_id}") if bindings[:object].teacher.present?
        end
      end
      field :schedule_name do
        label 'Horarios'
      end

      field :total_inscritos do
        label 'Tot Insc'
        column_width 40
        formatted_value do
          bindings[:object].total_academic_records
        end
      end


      field :cupos do
        label 'Cupos'
        column_width 40
        sortable 'sections.capacity'
        formatted_value do
          bindings[:object].capacity
        end        
      end

      field :qualified do
        column_width 40
      end
    end

    show do
      # field :name do
      #   label 'Descripción'
      # end
      # fields :teacher, :academic_records
      field :schedules do
        label 'Horario'
        formatted_value do
          value.name
        end
      end

      # field :schedule_table do
      #   label 'Horario'
      #   formatted_value do
      #     bindings[:view].render(partial: "schedules/on_table", locals: {schedules: bindings[:object].schedules})
      #   end
      # end

      field :desc_show do
        label 'Descripción'
        formatted_value do
          bindings[:view].render(partial: "sections/show_by_admin", locals: {section: bindings[:object]})
        end
      end
    end

    edit do
      field :code do
        # label do 
        #   if session[:academic_process_id]
        #     'Hola'
        #   else
        #     'Chau'
        #   end
        # end
        html_attributes do
          {:length => 8, :size => 8, :onInput => "$(this).val($(this).val().toUpperCase().replace(/[^A-Za-z0-9]/g,''))"}
        end
      end

      fields :course, :teacher, :modality

      field :classroom do
        html_attributes do
          {:onInput => "$(this).val($(this).val().toUpperCase().replace(/[^A-Za-z0-9]/g,''))"}
        end
      end

      field :capacity do
        html_attributes do
          {:min => 1}
        end
      end

      field :schedules

    end

    export do
      fields :period, :code, :subject, :user, :qualified, :modality, :schedules, :capacity

      field :total_students do 
        label 'Total inscritos'
        formatted_value do
          bindings[:object].total_students
        end
      end
    end
  end

  private

  def self.import row, fields

    total_newed = total_updated = 0
    no_registred = nil

    if row[0]
      row[0].strip!
    else
      return [0,0,0]
    end

    if row[1]
      row[1].strip!
      row[1].delete! '^A-Za-z|0-9'
    else
      return [0,0,1]
    end

    subject = Subject.find_by(code: row[1])
    subject ||= Subject.find_by(code: "0#{row[1]}")

    if subject
      # school = School.find (fields[:escuela_id])
      # period = Period.find (fields[:perido_id])
      
      academic_process = AcademicProcess.find fields[:academic_process_id]
      if academic_process
        if curso = Course.find_or_create_by(subject_id: subject.id, academic_process_id: academic_process.id)
          s = Section.find_or_initialize_by(code: row[0], course_id: curso.id)
          nueva = s.new_record?

          s.set_default_values_by_import if nueva

          if row[2]
            row[2].strip!
            row[2].delete! '^0-9'
            s.capacity = row[2]
          end

          if row[3]
            row[3].strip!
            row[3].delete! '^0-9'
            user = User.find_by(ci: row[3])
            s.teacher_id = user.id if user and user.teacher?
          end

          if s.save
            if nueva
              total_newed = 1
            else
              total_updated = 1
            end
          else
            no_registred = 0
          end
        else
          no_registred = 1 
        end
      else
        no_registred = 1
      end
    else
      no_registred = 1
    end
    [total_newed, total_updated, no_registred]
  end

  private


    def paper_trail_update
      # changed_fields = self.changes.keys - ['created_at', 'updated_at']
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      # self.paper_trail_event = "¡#{object} actualizado en #{changed_fields.to_sentence}"
      self.paper_trail_event = "#{object} actualizada."
    end  

    def paper_trail_create
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} registrada!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} eliminada!"
    end
end
