# frozen_string_literal: true

module Analytics
  module DoraMetricsAggregator
    class << self
      def aggregate_for(**params)
        data = ::Dora::DailyMetrics
          .for_environments(::Environment.for_project(params[:projects]).for_tier(params[:environment_tiers]))
          .in_range_of(params[:start_date], params[:end_date])
          .aggregate_for!(params[:metrics], params[:interval])

        post_process_deployment_frequency!(data, params)
      end

      private

      # The deployment frequency DB query returns the number of deployments which is not
      # the actual deployment frequency. To get the deployment frequency, we post-process
      # the data and calculate the average deployments within the time range.
      def post_process_deployment_frequency!(data, params)
        df_metric_name = Dora::DeploymentFrequencyMetric::METRIC_NAME

        return data unless params[:metrics].include?(df_metric_name)

        interval_day_counts = case params[:interval]
                              when Dora::DailyMetrics::INTERVAL_ALL
                                # number of days between a date range (inclusive)
                                { nil => (params[:end_date] - params[:start_date]).to_i + 1 }
                              when Dora::DailyMetrics::INTERVAL_MONTHLY
                                # Calculating the number of days monthly by iterating over the days
                                # since date ranges can be arbitrary, for example:
                                # 2022-01-15 - 2022-02-28
                                #
                                # - For January, 2022-01-01: 17 days
                                # - For February, 2022-02-01: 28 days
                                (params[:start_date]..params[:end_date]).each_with_object({}) do |date, hash|
                                  beginning_of_month = date.beginning_of_month
                                  hash[beginning_of_month] ||= 0
                                  hash[beginning_of_month] += 1
                                end
                              end

        data.each do |row|
          next if interval_day_counts.nil?
          next if row[df_metric_name].nil?

          row['deployment_count'] = row[df_metric_name]
          row[df_metric_name] = row[df_metric_name].fdiv(interval_day_counts[row['date']])
        end

        data
      end
    end
  end
end
