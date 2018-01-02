class ChangeNtdFormsLabel < ActiveRecord::DataMigration
  def up
    Form.find_by(controller: 'ntd_forms').update!(name: 'NTD Reporting') if Form.find_by(controller: 'ntd_forms').present?
  end
end