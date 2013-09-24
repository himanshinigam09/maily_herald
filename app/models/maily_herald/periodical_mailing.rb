module MailyHerald
  class PeriodicalMailing < Mailing
    attr_accessible :start, :start_var, :start_text, :period, :period_in_days

    validates   :context_name, :presence => true
    validates   :period, :presence => true, :numericality => {:greater_than => 0}

    def start_text
      @start_text || self.start.strftime(MailyHerald::TIME_FORMAT) if self.start
    end
    def start_text= date
      if date && !date.empty?
        date = Time.zone.parse(date) if date.is_a?(String)
        write_attribute(:start, date)
      else
        write_attribute(:start, nil)
      end
    end

    def period_in_days
      "%.2f" % (self.period.to_f / 1.day.seconds)
    end
    def period_in_days= d
      self.period = d.to_f.days
    end

    def context
      @context ||= MailyHerald.context self.context_name
    end

    def subscription_for entity
      subscription = self.subscriptions.for_entity(entity).first
      unless subscription 
        subscription = self.subscriptions.build
        subscription.entity = entity
        if self.autosubscribe && context.scope.include?(entity)
          subscription.active = true
          subscription.save!
        end
      end
      subscription
    end

    def deliver_to entity
      subscription = subscription_for entity
      return unless subscription.processable?
      unless subscription.conditions_met?
        Log.create_for self, entity, :skipped
        return
      end

      if self.mailer_name == 'generic'
        # TODO make it atomic
        mail = Mailer.generic(self, entity, subscription)
        mail.deliver
        Log.create_for self, entity, :delivered, {:content => mail.to_s}
      else
        # TODO
      end
    rescue StandardError => e
      Log.create_for self, entity, :error, {:msg => e.to_s}
    end

    def run
      current_time = Time.now
      self.context.scope.each do |entity|
        subscription = subscription_for entity
        next unless subscription.processable?

        if subscription.next_processing_time && (subscription.next_processing_time <= current_time)
          deliver_to entity
        end
      end
    end
  end
end
