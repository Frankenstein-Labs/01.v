# frozen_string_literal: true

module Admin
  class DataManagementController < Admin::ApplicationController
    feature_category :geo_replication
    urgency :low

    before_action :model_found?

    authorize! :read_admin_data_management, only: [:index, :show]

    def index; end

    def show
      @model = model_class.find(model_params[:id])
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    private

    def model_found?
      return render_404 if singular_model_name?

      render_404 unless model_class
    end

    def model_class
      @model_class ||= find_or_default_model_class
    end

    def find_or_default_model_class
      # Default model class is Project
      return Project if model_name.blank?

      ::Gitlab::Geo::ModelMapper.find_from_name(model_name)
    end

    def model_params
      params.permit(:model_name, :id)
    end

    def model_name
      @model_name ||= model_params[:model_name]&.singularize
    end

    def singular_model_name?
      model_name.present? && model_name == model_params[:model_name]
    end
  end
end
