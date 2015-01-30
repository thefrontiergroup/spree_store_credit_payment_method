require 'spec_helper'

describe 'Checkout', type: :feature, js: true do
  # Checkout setup
  context 'checkout setup' do
    let!(:country) { create(:country, states_required: true) }
    let!(:state) { create(:state) }
    let!(:shipping_method) { create(:shipping_method) }
    let!(:stock_location) { create(:stock_location) }
    let!(:mug) { create(:product, name: "RoR Mug") }
    let!(:payment_method) { create(:credit_card_payment_method) }
    let!(:store_credit_payment_method) { create(:store_credit_payment_method) }
    let!(:zone) { create(:zone) }
    let!(:user) { create(:user) }

    before do
      login_as_user
      shipping_method.calculator.update!(preferred_amount: 10)
      mug.shipping_category = shipping_method.shipping_categories.first
      mug.save!
    end

    before(:each) do
      stock_location.stock_items.update_all(count_on_hand: 1)
      add_mug_to_cart
    end

    context 'order fully covered by store credit' do
      let!(:store_credit) { create(:store_credit, user: user) }

      it 'should skip payment step and take store credits' do
        checkout_until_delivery_step
        expect(page).to_not have_content('PAYMENT')
        click_button "Save and Continue"
        order = Spree::Order.last
        expect(order.state).to eq('complete')
        expect(store_credit.reload.amount_used).to eq(order.total)
        expect(order.payments.last.source_type).to eq('Spree::StoreCredit')
        expect(order.payments.last.state).to eq('completed')
        expect(Spree::Payment.where(source_type: 'Spree::CreditCard').length).to eq(0)
      end
    end

    context 'order partially covered by store credit' do
      let!(:store_credit) { create(:store_credit, user: user, amount: 10) }

      it 'should ask for payment information when store credit does not fully cover an order' do
        checkout_until_delivery_step
        expect(page).to have_content('PAYMENT')
        click_button "Save and Continue"
        fill_in "Name on card", :with => 'Spree Commerce'
        fill_in "Card Number", :with => '4111111111111111'
        fill_in "card_expiry", :with => '04 / 20'
        fill_in "Card Code", :with => '123'
        click_button "Save and Continue"
        click_button "Place Order"
        order = Spree::Order.last
        expect(order.state).to eq('complete')
        payment_types = order.payments.collect(&:source_type)
        expect(payment_types.index("Spree::StoreCredit")).to_not eq(nil)
        expect(payment_types.index("Spree::CreditCard")).to_not eq(nil)
      end
    end

    context 'no store credit' do
      it 'should allow for normal checkout' do
        checkout_until_delivery_step
        expect(page).to have_content('PAYMENT')
        click_button "Save and Continue"
        fill_in "Name on card", :with => 'Spree Commerce'
        fill_in "Card Number", :with => '4111111111111111'
        fill_in "card_expiry", :with => '04 / 20'
        fill_in "Card Code", :with => '123'
        click_button "Save and Continue"
        click_button "Place Order"
        order = Spree::Order.last
        expect(order.state).to eq('complete')
        payment_types = order.payments.collect(&:source_type)
        expect(payment_types.index("Spree::StoreCredit")).to eq(nil)
        expect(payment_types.index("Spree::CreditCard")).to_not eq(nil)
      end
    end

    def checkout_until_delivery_step
      click_button "Checkout"
      fill_in_address
      click_button "Save and Continue"
    end

    def fill_in_address
      address = "order_bill_address_attributes"
      fill_in "#{address}_firstname", with: "Lucas"
      fill_in "#{address}_lastname", with: "Eggers"
      fill_in "#{address}_address1", with: "143 Swan Street"
      fill_in "#{address}_city", with: "Richmond"
      select "United States of America", from: "#{address}_country_id"
      select "Alabama", from: "#{address}_state_id"
      fill_in "#{address}_zipcode", with: "12345"
      fill_in "#{address}_phone", with: "(555) 555-5555"
    end

    def add_mug_to_cart
      visit spree.root_path
      click_link mug.name
      click_button "add-to-cart-button"
    end

    def login_as_user
      visit '/login'
      fill_in 'spree_user_email', with: user.email
      fill_in 'spree_user_password', with: user.password
      click_button 'Login'
    end
  end
end