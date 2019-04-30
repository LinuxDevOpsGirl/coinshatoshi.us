require_relative 'amqp_mock'

module Benchmark
  class Execution < Matching

    def initialize(label, num, round, process_num)
      super(label, num, round)
      @process_num = process_num
    end

    def execute_trades
      t1 = Trade.count

      @instructions.in_groups(@process_num, false).each_with_index do |insts, i|
        unless Process.fork
          ActiveRecord::Base.connection.reconnect!
          puts "Executor #{i+1} started."

          t1 = Time.now
          insts.each do |payload|
            ::Matching::Executor.new(payload).execute!
          end

          puts "Executor #{i+1} finished work, stop."
          exit 0
        end
      end
      pid_and_status = Process.waitall

      ActiveRecord::Base.connection.reconnect!
      @trades = Trade.count - t1

    end

    def run_execute_trades
      puts "\n>> Execute Trade Instructions"
      Benchmark.benchmark(Benchmark::CAPTION, 20, Benchmark::FORMAT) do |x|
        t = x.report { execute_trades }
        @times[:execution] = [t]
        puts "#{@instructions.size} trade instructions executed by #{@process_num} executors, #{@trades} trade created."
      end
    end

  end
end
