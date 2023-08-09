class PaymentReport < ApplicationRecord
  # SCHEMA:
  # t.float "amount"
  # t.string "transaction_id"
  # t.integer "transaction_type"
  # t.date "transaction_date"
  # t.bigint "origin_bank_id", null: false
  # t.string "payable_type"
  # t.bigint "payable_id"  
  # t.bigint "receiving_bank_account_id"  

  # HISTORY:
  has_paper_trail on: [:create, :destroy, :update]

  before_create :paper_trail_create
  before_destroy :paper_trail_destroy
  before_update :paper_trail_update

  # ASSOCIATIONS:
  belongs_to :origin_bank, class_name: 'Bank', foreign_key: 'origin_bank_id'
  belongs_to :payable, polymorphic: true
  belongs_to :receiving_bank_account, class_name: 'BankAccount'

  has_one_attached :voucher do |attachable|
    attachable.variant :thumb, resize_to_limit: [100,100]
  end

  attr_accessor :remove_voucher
  after_save { voucher.purge if remove_voucher.eql? '1' }   

  # VALIDATIONS:
  # validates :payable_id, presence: true
  # validates :payable_type, presence: true
  validates :payable, presence: true
  validates :amount, presence: true
  validates :transaction_id, presence: true
  validates :transaction_type, presence: true
  validates :transaction_date, presence: true
  validates :origin_bank, presence: true
  validates :receiving_bank_account, presence: true

  enum transaction_type: [:transferencia, :efectivo, :punto_venta]

  rails_admin do
    navigation_label 'Administrativa'
    navigation_icon 'fa-solid fa-cash-register'

    edit do
      field :amount
      field :transaction_id do
        html_attributes do
          {:length => 20, :size => 20, :onInput => "$(this).val($(this).val().toUpperCase().replace(/[^0-9]/g,''))"}
        end
      end
      field :payable do
        label 'Entidad a Pagar'
      end
      field :transaction_type
      field :origin_bank do
        inline_edit false
        inline_add false
      end
    end

    export do
      fields :amount, :transaction_id, :transaction_type, :transaction_date, :origin_bank, :origin_bank
      field :payable_type do
        label 'Tipo'
      end
      field :payable_id do
        label 'Id'
      end

    end
  end  

  private


    def paper_trail_update
      # changed_fields = self.changes.keys - ['created_at', 'updated_at']
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      # self.paper_trail_event = "¡#{object} actualizado en #{changed_fields.to_sentence}"
      self.paper_trail_event = "¡#{object} actualizado!"
    end  

    def paper_trail_create
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡#{object} registrado!"
    end  

    def paper_trail_destroy
      object = I18n.t("activerecord.models.#{self.model_name.param_key}.one")
      self.paper_trail_event = "¡Reporte de Pago eliminado!"
    end

end
