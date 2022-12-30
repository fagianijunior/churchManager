class Administration < ApplicationRecord
  belongs_to :user
  belongs_to :occupation
  
  validates :user_id, :occupation_id, :start_date, presence: true

end
