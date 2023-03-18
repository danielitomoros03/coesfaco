class EnrollAcademicProcessesController < ApplicationController
  before_action :set_enroll_academic_process, only: %i[ show edit update destroy ]

  # GET /enroll_academic_processes or /enroll_academic_processes.json
  def index
    @enroll_academic_processes = EnrollAcademicProcess.all
  end

  # GET /enroll_academic_processes/1 or /enroll_academic_processes/1.json
  def show
  end

  # GET /enroll_academic_processes/new
  def new
    @enroll_academic_process = EnrollAcademicProcess.new
  end

  # GET /enroll_academic_processes/1/edit
  def edit
  end

  def reserve_space
    begin
      # LIBERAR CUPO
      academic_record = AcademicRecord.joins(:course, :grade).where('courses.id': params[:course_id],'grades.id': params[:grade_id]).first

      if academic_record and academic_record.destroy
        msg = "Cupo liberado"
        estado = 'success'
      else
        msg = "Sin Inscripción"
        estado = 'error'
      end

      if (params[:section_id] and !params[:section_id].blank?)
        # INSCRIBIR EN SECCIÓN
        section = Section.find params[:section_id]
        # grade = Grade.find params[:grade_id]
        course = section.course
        academic_process = course.academic_process
        limit_credits = academic_process.max_credits
        limit_subjects = academic_process.max_subjects

        # BUSCAR INSCRIPCIÓN:
        enroll_academic_process = EnrollAcademicProcess.find_or_initialize_by(academic_process_id: academic_process.id, grade_id: params[:grade_id])

        if enroll_academic_process.new_record?
          enroll_academic_process.permanence_status = :regular
          enroll_academic_process.enroll_status = :reservado 
          enroll_academic_process.save!
        end
        enroll_academic_process
        if enroll_academic_process
          # INTENTO POR TOTAL DE CREDITOS Y ASIGNATURAS: 
          credits_attemp = enroll_academic_process.total_credits+course.subject.unit_credits
          subjects_attemp = enroll_academic_process.total_subjects+1

          if credits_attemp > limit_credits
            # EXCESO DE CRÉDITOS
            estado = 'error'
            msg = "Supera el límite de créditos permitidos para este proceso de inscripción. Por favor, corrija su selección de créditos e inténtelo de nuevo. (#{credits_attemp} / #{limit_credits})"
          
          elsif subjects_attemp > limit_subjects
            # EXCESO DE ASIGNATURAS
            estado = 'error'
            msg = "Supera el límite de asignaturas permitidas para este proceso de inscripción. Por favor, corrija su selección de asignaturas e inténtelo de nuevo. (#{credits_attemp} / #{limit_credits})"

          elsif !(section.has_capacity?)
            # SIN CUPOS
            msg = "Sin cupos disponibles para: #{sec.descripcion} en el período #{sec.periodo.id}"
            estado = 'error'
          else
            # VALIDA PARA INSCRIBIR
            academic_record = AcademicRecord.new(section_id: section.id, enroll_academic_process_id: enroll_academic_process.id, status: :sin_calificar)

            if academic_record.save

              if enroll_academic_process.update(enroll_status: :reservado)
                msg = "Cupo reservado"
                estado = 'success'
              else
                estado = 'error'
                msg = "Error: #{enroll_academic_process.errors.full_messages.to_sentence}"
              end
            else
              estado = 'error'
              msg = "Error: #{academic_record.errors.full_messages.to_sentence}"
            end
          end
        end
      end

    rescue Exception => e
      estado = 'error'
      msg = "Error: #{e}"       
    end
    cupo = section ? section.description_with_quotes : 'Seleccione Sección'
    respond_to do |format|
      format.json do 
        render json: {data: msg, status: estado, cupo: cupo}
      end

    end
  end

  def enroll
    enroll_academic_process = EnrollAcademicProcess.where(grade_id: params[:grade_id], academic_process_id: params[:academic_process_id]).first
    any_error = false
    if enroll_academic_process.nil?
      flash[:danger] = 'No realizó inscripción alguna. Por favor, selección las asignaturas e inténtelo nuevamente. Tenga en cuenta que al seleccionar una sección en cada asignatura, debe aparecer un mensaje afirmativo de completación de la reserva del cupo.'
    elsif !(enroll_academic_process.academic_records.any?)
      flash[:danger] = 'Sin selección se asignaturas. Por favor, selección alguna asignaturas e inténtelo nuevamente. Tenga en cuenta que al seleccionar una sección en cada asignatura, debe aparecer un mensaje afirmativo de completación de la reserva del cupo.'
      any_error = true
    elsif (enroll_academic_process.total_credits > enroll_academic_process.academic_process.max_credits)
      flash[:danger] = "Supera el límite de créditos permitidos para este proceso de inscripción. Por favor, corrija su selección e inténtelo de nuevo. Se anularon las selecciones hechas con anteridad."
      any_error = true
    elsif (enroll_academic_process.total_subjects > enroll_academic_process.academic_process.max_subjects)
      flash[:danger] = "Supera el límite de asignaturas permitidas para este proceso de inscripción. Por favor, corrija su inscripción e inténtelo de nuevo. Se anularon las selecciones previas."
      
      any_error = true      
    elsif (enroll_academic_process.update(enroll_status: :preinscrito))
      # info_bitacora "Estudiante #{enroll_academic_process.estudiante_id} Preinscrito en el periodo #{enroll_academic_process.periodo.id} en #{enroll_academic_process.escuela.descripcion}.", Bitacora::CREACION, enroll_academic_process
      begin
        # info_bitacora "Envío de correo de Preinscripcion #{enroll_academic_process.estudiante_id} Preinscrito en el periodo #{enroll_academic_process.periodo.id} en #{enroll_academic_process.escuela.descripcion}.", Bitacora::CREACION, enroll_academic_process if EstudianteMailer.preinscrito(enroll_academic_process.estudiante.usuario, enroll_academic_process).deliver

        EstudianteMailer.preinscrito(enroll_academic_process.estudiante.usuario, enroll_academic_process).deliver
        
      rescue Exception => e
        flash[:warning] = "Correo de completación de proceso de preinscripción no enviado: #{e}" 
      end
      flash[:success] = "Proceso de preinscripción completado con éxito. Un correo con el resumen del proceso le ha sido enviado."

      flash[:info] = "Asignaturas Inscritas: #{enroll_academic_process.total_subjects}. Créditos Inscritos: #{enroll_academic_process.total_credits}"
    else
      flash[:danger] = "Error al intentar completar el procesos de preinscripción: #{enroll_academic_process.errors.full_messages.to_sentence}"
      any_error = true
    end
    enroll_academic_process.destroy if any_error
    redirect_back fallback_location: 'student_session/dashboard'
  end

  # POST /enroll_academic_processes or /enroll_academic_processes.json
  def create
    @enroll_academic_process = EnrollAcademicProcess.new(enroll_academic_process_params)

    respond_to do |format|
      if @enroll_academic_process.save
        format.html { redirect_to enroll_academic_process_url(@enroll_academic_process), notice: "Enroll academic process was successfully created." }
        format.json { render :show, status: :created, location: @enroll_academic_process }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @enroll_academic_process.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /enroll_academic_processes/1 or /enroll_academic_processes/1.json
  def update
    respond_to do |format|
      if @enroll_academic_process.update(enroll_academic_process_params)
        format.html { redirect_to enroll_academic_process_url(@enroll_academic_process), notice: "Enroll academic process was successfully updated." }
        format.json { render :show, status: :ok, location: @enroll_academic_process }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @enroll_academic_process.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /enroll_academic_processes/1 or /enroll_academic_processes/1.json
  def destroy
    @enroll_academic_process.destroy

    respond_to do |format|
      format.html { redirect_to enroll_academic_processes_url, notice: "Enroll academic process was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_enroll_academic_process
      @enroll_academic_process = EnrollAcademicProcess.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def enroll_academic_process_params
      params.require(:enroll_academic_process).permit(:grade_id, :academic_process_id, :enroll_status, :permanence_status)
    end
end
