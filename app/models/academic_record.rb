class AcademicRecord < ApplicationRecord
  # SCHEMA:
  # t.bigint "section_id", null: false
  # t.bigint "enroll_academic_process_id", null: false
  # t.integer "status"

  # ENUMERIZE:
  enum status: [:sin_calificar, :aprobado, :aplazado, :retirado, :perdida_por_inasistencia, :equivalencia_interna, :equivalencia_externa]

  # ASSOCIATIONS:
  belongs_to :section
  belongs_to :enroll_academic_process

  has_many :qualifications, dependent: :destroy

  has_one :academic_process, through: :enroll_academic_process
  has_one :grade, through: :enroll_academic_process
  has_one :study_plan, through: :grade
  has_one :student, through: :grade
  has_one :address, through: :student
  has_one :user, through: :student
  has_one :period, through: :academic_process
  has_one :period_type, through: :period
  has_one :course, through: :section
  has_one :teacher, through: :section
  has_one :subject, through: :course

  # VALIDATIONS:
  validates :section, presence: true
  validates :enroll_academic_process, presence: true
  validates :status, presence: true

  # CALLBACK
  after_save :set_options_q
  after_save :update_grade_numbers#, if: :will_save_change_to_status?

  # TRIGGER FUNCTIONS:
  def set_options_q
    self.qualifications.destroy_all if self.pi? or self.retirado? or (self.subject and self.subject.absoluta?)
  end

  # SCOPE:
  scope :custom_search, -> (keyword) { joins(:user, :subject).where("users.ci ILIKE '%#{keyword}%' OR users.email ILIKE '%#{keyword}%' OR users.first_name ILIKE '%#{keyword}%' OR users.last_name ILIKE '%#{keyword}%' OR users.number_phone ILIKE '%#{keyword}%' OR subjects.name ILIKE '%#{keyword}%' OR subjects.code ILIKE '%#{keyword}%'") }

  scope :prenroll, -> {joins(:enroll_academic_process).where('enroll_academic_processes.enroll_status = ?', :preinscrito)}

  scope :confirmed, -> {joins(:enroll_academic_process).where('enroll_academic_processes.enroll_status = ?', :confirmado)}

  scope :with_totals, ->(school_id, period_id) {joins(:school).where("schools.id = ?", school_id).of_period(period_id).joins(:user).joins(:subject).joins(grade: :study_plan).group(:grade_id).select('study_plans.id plan_id, study_plans.total_credits plan_creditos, grados.*, SUM(subjects.unit_credits) total_creditos, COUNT(*) subjects, SUM(IF (academic_records.status = 1, subjects.creditos, 0)) aprobados')}

  scope :of_period, lambda { |period_id| joins(:academic_proccess).where "academic_process.period_id = ?", period_id}
  scope :of_periods, lambda { |periods_ids| joins(:academic_proccess).where "academic_process.period_id IN (?)", periods_ids}

  scope :on_reparacion, -> {joins(:qualifications).where('qualificactions.type_q': :reparacion)}

  scope :of_school, lambda {|school_id| includes(:school).where("schools.id = ?", school_id).references(:schools)}
  scope :of_schools, lambda {|schools_ids| includes(:school).where("schools.id IN (?)", schools_ids).references(:schools)}

  scope :of_student, lambda {|student_id| where("student_id = ?", student_id)}

  scope :no_retirados, -> {where "academic_records.status != 3"}

  scope :coursed, -> {where "academic_records.status = 1 or academic_records.status = 2 or academic_records.status = 4"}

  scope :coursing, -> {where "academic_records.status != 1 and academic_records.status != 2 and academic_records.status != 3"} # Excluye retiradas también
  
  scope :total_credits_coursed_on_periods, lambda{|periods_ids| coursed.joins(:academic_proccess).where('academic_proccesses.period_id IN (?)', periods_ids).joins(:subject).sum('subjects.unit_credits')}

  scope :total_credits_approved_on_periods, lambda{|periods_ids| aprobado.joins(:academic_proccess).where('academic_proccesses.period_id IN (?)', periods_ids).joins(:subject).sum('subjects.unit_credits')}

  scope :total_credits, -> {joins(:subject).sum('subjects.unit_credits')}

  scope :total_credits_coursed, -> {coursed.total_credits}
  scope :total_credits_approved, -> {aprobado.total_credits}
  
  scope :weighted_average, -> {joins(:subject).joins(:qualifications).coursed.sum('subjects.unit_credits * qualifications.value')}

  scope :promedio, -> {joins(:qualifications).coursed.average('qualifications.value')}
  scope :promedio_approved, -> {aprobado.promedio}
  scope :weighted_average_approved, -> {aprobado.weighted_average}

  scope :sin_equivalencias, -> {joins(:section).not_equivalencia_interna} 

  scope :by_equivalencia, -> {joins(:section).equivalencia_interna}

  # scope :by_equivalencia_interna, -> {joins(:section).where "sections.modality = 1"}
  # scope :by_equivalencia_externa, -> {joins(:section).where "sections.modality = 2"}

  scope :student_enrolled_by_period, lambda { |period_id| joins(:academic_proccess).where("academic_proccesses.period_id": period_id).group(:student).count } 

  scope :total_by_qualification_modality?, -> {joins(:subject).group("subjects.modality").count}

  scope :students_enrolled, -> { group(:student_id).count } 

  scope :student_enrolled_by_credits, -> { joins(:subject).group(:student_id).sum('subject.unit_credits')} 

  # Esta función retorna la misma cuenta agrupadas por creditos de asignaturas
  scope :student_enrolled_by_credits2, -> { joins(:subject).group('academic_records.student_id', 'subjects.unit_credits').count} 

  # scope :perdidos, -> {perdida_por_inasistencia}


  # FUNCTIONS:

  def set_status valor
    valor.strip!
    valor.upcase!

    if (valor.eql? 'PI' or valor.eql? 'RT' or valor.eql? 'A' or valor.eql? 'AP' or valor.eql? 'EQ')
      self.status = I18n.t(valor)
      return true
    else
      qua = self.qualifications.find_or_initialize_by(type_q: :final)
      qua.value = valor.to_i
      return qua.save
    end
    return false
  end

  def student_name_with_retiro
    aux = "#{user.reverse_name}"
    aux += " <div class='badge bg-danger'>Retirada</div>" if retirado? 
    return aux
  end

  def tr_class_by_status_q
    valor = ''
    valor = 'table-success' if self.aprobado?
    valor = 'table-danger' if (self.aplazado? || self.retirado? || self.pi?)
    valor += ' text-muted' if self.retirado?
    return valor
  end

  def name
    "#{user.ci_fullname} en #{section.name}" if (user and section)
  end

  def pi?
    perdida_por_inasistencia?
  end

  def preinscrito_in_process?
    self.enroll_academic_process and self.enroll_academic_process.preinscrito?
  end

  def post_q?
    !post_q.nil?
  end

  def diferido?
    (post_q and post_q.diferido?) ? true : false
  end

  def reparacion?
    (post_q and post_q.reparacion?) ? true : false
  end

  def definitive_q
    aux = post_q
    aux ? aux : final_q
  end

  def definitive_q_value
    definitive_q ? definitive_q.value : nil
  end  

  def final_q
    aux = qualification_by :final
    aux ? aux : nil
  end

  def post_q
    aux = qualification_by [:diferido, :reparacion]
    aux ? aux : nil
  end

  def qualification_by type_q
    self.qualifications.by_type_q(type_q).first
  end

  def definitive_label
    definitive_q ? q_value_to_02i : I18n.t(self.status)
  end

  def type_q_label
    if subject.absoluta?
      'Absoluta'
    else
      definitive_q ? definitive_q.type_q.titleize : 'Final' 
    end
  end

  def final_q_to_02i
    q_value_to_02i final_q
  end

  def final_q_to_02i_to_from
    q_value_to_02i_to_from final_q
  end

  def final_type_q
    final_q ? final_q.type_q : nil
  end

  def final_q_value 
    q_value final_q
  end

  def post_q_value 
    q_value post_q
  end

  def q_value qualification=definitive_q
    qualification ? qualification.value : nil
  end

  def post_type_q
    post_q ? post_q.type_q : nil
  end

  def post_q_to_02i
    q_value_to_02i post_q
  end

  def post_type_q
    post_q ? post_q.type_q : nil
  end

  def definitive_type_q
    definitive_q ? definitive_q.type_q : :final
  end

  def q_value_to_02i_to_from qualification=definitive_q
    qualification ? qualification.value_to_02i : nil
  end
  def q_value_to_02i qualification=definitive_q
    qualification ? qualification.value_to_02i : '--'
  end

  def description_q force_final = false
    qualification = force_final ? final_q : definitive_q
    qualification ? (num_to_s qualification) : self.status.to_s.humanize.upcase 
  end

  def num_to_s num = definitive_q_value 
    if pi? or retirado? or (subject and subject.absoluta?) or num.nil? or !(num.is_a? Integer or num.is_a? Float)
      status.humanize.upcase
    else
      numeros = %W(CERO UNO DOS TRES CUATRO CINCO SEIS SIETE OCHO NUEVE DIEZ ONCE DOCE TRECE CATORCE QUINCE DIECISÉIS DIECISIETE DIECIOCHO DIE)
      # dieciséis, diecisiete, dieciocho y diecinueve
      num = num.to_i
        
      if num < 10 
        "#{numeros[0]} #{numeros[num]}"
      elsif num >= 10  and num < 16
        numeros[num]
      elsif num >= 16 and num < 20
        aux = num % 10
        "#{numeros[10]} Y #{numeros[aux]}"
      elsif num == 20
        'VEINTE'
      else
        'INVÁLIDA'
      end
    end
  end

  def conv_descrip force_final = false # convocados

    data = [self.user.ci, self.user.reverse_name, self.study_plan.code]

    if force_final
      data << I18n.t('aplazado')
      data << I18n.t('final')
      data << self.q_value_to_02i(final_q)
      data << self.description_q(true)
    else
      data << I18n.t(self.status)
      data << I18n.t(self.definitive_type_q)
      data << self.q_value_to_02i #unless self.subject.as_absolute?
      data << self.description_q
    end

    return data

  end

  # RAILS_ADMIN
  rails_admin do
    navigation_label 'Inscripciones'
    navigation_icon 'fa-solid fa-signature'

    list do
      search_by :custom_search
      fields :period, :section, :student do
        searchable :name
        filterable :name
        sortable :name
      end
      field :definitive_label do
        label 'Definitiva'
      end
      field :status do
        label 'Estado'
      end
      field :type_q_label do
        label 'Tipo'
      end
    end

    edit do
      fields :section, :enroll_academic_process, :status, :qualifications
    end

    export do
      fields :section, :enroll_academic_process, :status, :qualifications, :period, :period_type, :student, :user, :address, :subject
    end
  end  

  private

  def self.import row, fields

    total_newed = total_updated = 0
    no_registred = nil

    # BUSCAR PERIODO
    if row[3]
      row[3].strip!
      row[3].upcase!
    end
    row[3] = fields[:nombre_periodo] if row[3].blank?

    period = Period.find_by_name(row[3]) 

    if period
      # LIMPIAR CI
      if row[0]
        row[0].strip!
        row[0].delete! '^0-9'
      else
        return [0,0,0]
      end

      # LIMPIAR CODIGO ASIGNATURA
      if row[1]
        row[1].strip!
      else
        return [0,0,1]
      end

      subject = Subject.find_by(code: row[1])
      subject ||= Subject.find_by(code: "0#{row[1]}")

      if !subject.nil?
        p "     SUBJECT: #{subject.name}    ".center(300, "U")
        study_plan = StudyPlan.find fields[:study_plan_id]
        if !study_plan.nil?
          p "     STUDY PLAN: #{study_plan.name}    ".center(300, "P")

          escuela = study_plan.school
          # BUSCAR O CREAR PROCESO ACADEMICO:
          academic_process = AcademicProcess.find_or_initialize_by(period_id: period.id, school_id: escuela.id)
          academic_process.default_value_by_import if academic_process.new_record?

          if academic_process.save
            # BUSCAR O CREAR EL CURSOS (PROGRAMACIÓN):
            p "     ACADEMIC PROCESS: #{academic_process.name}    ".center(300, "P")

            if curso = Course.find_or_create_by(subject_id: subject.id, academic_process_id: academic_process.id)

              # BUSCAR O CREAR SECCIÓN
              if row[2]
                row[2].strip!
              else
                return [0,0,2]
              end

              s = Section.find_or_initialize_by(code: row[2], course_id: curso.id)
              s.set_default_values_by_import if s.new_record?

              if s.save
                p "     SECTION: #{s.name}    ".center(300, "S")

                # BUSCAR USUARIO
                user = User.find_by(ci: row[0])
              
                if user and user.student?

                  if stu = user.student
                    p "     STUDENT: #{stu.user_ci}    ".center(300, "E")

                    # BUSCAR O CREAR GRADO
                    grade = Grade.find_by(study_plan_id: study_plan.id, student_id: stu.id)
                    if !grade.nil?
                      p "     GRADE: #{grade.name}    ".center(300, "G")

                      # BUSCAR O CREAR INSCRIPCIÓN PROCESO ACADEMICO:
                      enroll_academic_process = EnrollAcademicProcess.find_or_initialize_by(academic_process_id: academic_process.id, grade_id: grade.id)

                      enroll_academic_process.set_default_values_by_import if enroll_academic_process.new_record?

                      if enroll_academic_process.save
                        p "     ENROLL ACADEMIC PROCESS: #{enroll_academic_process.name}    ".center(300, "E")
                        # BUSCAR O CREAR REGISTRO ACADEMICO
                        academic_record = AcademicRecord.find_or_initialize_by(section_id: s.id, enroll_academic_process_id: enroll_academic_process.id)
                        
                        nuevo = academic_record.new_record?

                        if academic_record.save!
                          p "     EXITO. GUARDADO EL REGISTRO ACADEMICO: #{academic_record.name}    ".center(500, "#")
                          if row[4]
                            row[4].strip! 
                            calificacion_correcta = academic_record.set_status row[4]
                            if (calificacion_correcta.eql? true and academic_record.save!)
                              nuevo ? total_newed = 1 : total_updated = 1
                            else
                              no_registred = 'valor nota'
                            end
                          else
                            nuevo ? total_newed = 1 : total_updated = 1
                          end
                        else
                          no_registred = 'registro academico'
                        end
                      else
                        no_registred = 'proceso academico'
                      end
                    else
                      no_registred = 'grado'
                    end
                  else
                    no_registred = 'estudiante'
                  end

                else
                  no_registred = 'error'
                end

              else
                no_registred = 2
              end
            else
              no_registred = 1 
            end
          else
            no_registred = 0 # Proceso Academico
          end
        else
          no_registred = 1 # Study Plan
        end
      else
        no_registred = 1
      end
    else
      no_registred = 3
    end
    
    [total_newed, total_updated, no_registred]
  end

  private

  def update_grade_numbers

    self.grade.update(efficiency: self.grade.calculate_efficiency, simple_average: self.grade.calculate_average, weighted_average: self.grade.calculate_weighted_average)
  end

end
