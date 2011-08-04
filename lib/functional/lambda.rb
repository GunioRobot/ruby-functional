require 'functional/bind'

module Lambda
  def lambda?(obj) return obj.respond_to?(:lambda?) && obj.lambda? end
  def protected?(obj) return obj.respond_to?(:protected?) && obj.protected? end
  def bound?(obj) return lambda?(obj) && !protected?(obj) end

  def protect(obj)
    obj.protect if obj.respond_to?(:protect)
    return obj
  end

  def unprotect(obj)
    obj.unprotect if obj.respond_to?(:unprotect)
    return obj
  end

  module_function :lambda?, :protected?, :bound?, :protect, :unprotect

  module Primitive
    def protect(obj) return Lambda.protect(obj) end
  end

  module Variable
    def method_missing(name, *args)
      v = Internal::Variable.new(name)
      return v if args.length==0 && v.argument_index?
      return super
    end
  end

  module Expression
    alias :_method_missing :method_missing
    def method_missing(name, *args)
      if lambda?
        name = name.to_s
        name = name[1..-1] if name =~ /^_/
        return name.to_sym[self, *args]
      end
      return _method_missing(name, *args)
    end

    def protect()
      @protect = 0 unless @protect
      @protect += 1
      return self
    end

    def unprotect()
      @protect = 1 if !@protect || @protect < 1
      @protect -= 1
      return self
    end

    def protected?() return @protect && @protect > 0 end
  end

  module Statement
    def if_(cond, &block)
      cond = cond.to_lambda
      block = Internal::If.bind(&block)
      holder = { :cond => cond, :then => block, :else => nil }

      return Internal::If.new do |*args|
        if cond.call(*args)
          block.call(*args)
        elsif holder[:else]
          holder[:else].call(*args)
        end
      end.__send__(:set_place_holder, holder)
    end

    def unless_(cond, &block)
      return if_(cond ^ true, &block)
    end
  end
end

require 'functional/lambda/internal'

class Proc
  class Bind
    def self.fill(formal, actual)
      return formal.map do |a|
        Lambda.bound?(a) ? a.call(*actual) : Lambda.unprotect(a)
      end
    end

    include Lambda::Expression

    def lambda?() return true end
  end
end

class Symbol
  include Lambda::Expression

  def lambda?() return argument_index? end
end

class Object
  def to_lambda() Lambda.lambda?(self) ? self : proc{|x|x}.bind(self) end
end