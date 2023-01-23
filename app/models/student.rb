class Student < ApplicationRecord

  # SCHEMA:
  # t.boolean "active", default: true
  # t.integer "disability"
  # t.integer "nacionality"
  # t.integer "marital_status"
  # t.string "origin_country"
  # t.string "origin_city"
  # t.date "birth_date"  

  # GLOBALS VARIABLES:
  ESTADOS_CIVILES = ['Soltero/a', 'Casado/a', 'Concubinato', 'Divorciado/a', 'Viudo/a']
  NACIONALIDAD = ['Venezolano/a', 'Venezolano/a Nacionalizado/a', 'Extranjero/a']

  DISCAPACIDADES = ['Sensorial Visual', 'Sensorial Auditiva', 'Motora Miembros Inferiores', 'Motora Medios Superiores', 'Motora Ambos Miembros']

  enum nacionality: NACIONALIDAD
  enum disability: DISCAPACIDADES
  enum marital_status: ESTADOS_CIVILES

  # ASSOCIATIONS:
  #belons_to
  belongs_to :user
  # has_one
  has_one :location
  # has_many
  has_many :grades

  # VALIDATIONS:
  validates :user, presence: true, uniqueness: true
  validates :nacionality, presence: true, unless: :new_record?
  validates :marital_status, presence: true, unless: :new_record?
  validates :origin_country, presence: true, unless: :new_record?
  validates :origin_city, presence: true, unless: :new_record?
  validates :birth_date, presence: true, unless: :new_record?
  validates :location, presence: true, unless: :new_record?
  # How to validate if student is not created for assosiation

  # SCOPES:
  scope :custom_search, -> (keyword) { joins(:user).where("users.ci LIKE '%#{keyword}%' OR users.email LIKE '%#{keyword}%' OR users.first_name LIKE '%#{keyword}%' OR users.last_name LIKE '%#{keyword}%' OR users.number_phone LIKE '%#{keyword}%'") }

  # CALLBACKS:
  after_destroy :check_user_for_destroy
  
  # HOOKS:
  def check_user_for_destroy
    user_aux = User.find self.user_id
    user_aux.delete if user_aux.without_rol?
  end


  # FUNCTIONS:

  def name
    user.description if user
  end

  def user_ci
    self.user.ci if self.user
  end


  
  rails_admin do
    navigation_label 'Gestión de Usuarios'
    navigation_icon 'fa-regular fa-user-graduate'

    edit do
      field :user do
        # searchable :full_name
      end
      fields :nacionality, :origin_country, :origin_city, :birth_date, :marital_status, :location
      # field :nacionality do
      #   formatted_value do 
      #     value.to_s.upcase
      #   end
      # end
    end

    show do
      fields :user, :nacionality, :origin_country, :origin_city, :birth_date, :marital_status, :location, :created_at
    end

    list do
      search_by :custom_search
      fields :user, :origin_city, :birth_date, :marital_status, :created_at
    end

    export do
      fields :user, :nacionality, :origin_country, :origin_city, :birth_date, :marital_status, :location, :created_at
    end

  end


end
