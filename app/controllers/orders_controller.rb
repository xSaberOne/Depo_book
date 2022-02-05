# frozen_string_literal: true

class OrdersController < ApplicationController
  include CurrentCart
  before_action :set_cart, only: %i[new create]
  before_action :ensure_cart_is_not_empty, only: :new
  before_action :set_order, only: %i[show edit update destroy]

  # GET /orders or /orders.json
  def index
    @orders = Order.all
  end

  # GET /orders/1 or /orders/1.json
  def show; end

  # GET /orders/new
  def new
    @order = Order.new
  end

  # GET /orders/1/edit
  def edit; end

  # POST /orders or /orders.json
  def create
    @order = Order.new(order_params)
    @order.add_line_items_from_cart(@cart)
    respond_to do |format|
      if @order.save
        @cart.line_items.each do |line_item|
          line_item.product.update!(times_bought: line_item.product.times_bought + line_item.quantity)
        end
        @products = Product.all
        ActionCable.server.broadcast 'products', html: render_to_string('layouts/_top_list', layout: false)
        Cart.destroy(session[:cart_id])
        session[:cart_id] = nil
        OrderMailer.received(@order).deliver_later
        format.html { redirect_to store_index_url, notice: 'Thank you for your order.' }
        format.json { render :show, status: :created, location: @order }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /orders/1 or /orders/1.json
  def update
    respond_to do |format|
      if @order.update(order_params)
        format.html { redirect_to order_url(@order), notice: 'Order was successfully updated.' }
        format.json { render :show, status: :ok, location: @order }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /orders/1 or /orders/1.json
  def destroy
    @order.destroy

    respond_to do |format|
      format.html { redirect_to orders_url, notice: 'Order was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_order
    @order = Order.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def order_params
    params.require(:order).permit(:name, :address, :email, :pay_type)
  end

  def ensure_cart_is_not_empty
    redirect_to store_index_url, notice: 'Your cart is empty' if @cart.line_items.empty?
  end

  def pay_type_params
    case order_params[:pay_type]
    when 'Credit card'
      params.require(:order).permit(:credit_card_number, :expiration_date)
    when 'Check'
      params.require(:order).permit(:routing_number, :account_number)
    when 'Purchase order'
      params.require(:order).permit(:po_number) else
      {}
    end
  end
end
