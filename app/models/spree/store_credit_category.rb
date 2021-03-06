class Spree::StoreCreditCategory < ActiveRecord::Base
  GIFT_CARD_CATEGORY_NAME = 'Gift Card'
  DEFAULT_NON_EXPIRING_TYPES = [GIFT_CARD_CATEGORY_NAME]

  def non_expiring?
    non_expiring_category_types.include? name
  end

  def non_expiring_category_types
    DEFAULT_NON_EXPIRING_TYPES | Spree::StoreCredits::Configuration.non_expiring_credit_types
  end
end
