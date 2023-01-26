class Admin < ApplicationRecord
  # SCHEMA:
  # t.bigint "user_id", null: false
  # t.integer "role"
  # t.string "env_authorizable_type", default: "Faculty"
  # t.bigint "env_authorizable_id"

  # ENUMERIZE:
  enum role: [:super, :jefe_control_estudio, :director, :jefe_departamento, :asistente]

  # ASSOCIATIONS:
  belongs_to :user
  belongs_to :env_authorizable, polymorphic: true
  belongs_to :profile, optional: true

  # VALIDATIONS:
  validates :user, presence: true, uniqueness: true
  validates :env_authorizable, presence: true
  validates :user, presence: true
  validates :role, presence: true

  # validates :env_authorizable_type, presence: true

  def yo?
    self.user.email.eql? 'moros.daniel@gmail.com' and self.user_id.eql? 1
  end

  # CALLBACKS:
  after_destroy :check_user_for_destroy
  
  # HOOKS:
  def check_user_for_destroy
    user_aux = User.find self.user_id
    user_aux.delete if user_aux.without_rol?
  end  

  rails_admin do
    navigation_label 'Gestión de Usuarios'
    navigation_icon 'fa-regular fa-user-tie'

    show do
     field :user 
     field :role 
     field :env_authorizable 
     field :created_at
    end

    list do
      field :user
      field :role
      field :env_authorizable
      field :created_at
    end

    edit do
       field :user 
       field :role 
       field :env_authorizable

      # field :role do
      #   html_attributes do
      #     {:onChange => "alert($(this).val())"}

      #   end
      # end
    end

    export do
      field :role
      field :user
    end
  end
end
