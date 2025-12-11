module StringColors
  refine String do
    def red
      "\e[31m#{self}\e[0m"
    end

    def yellow
      "\e[33m#{self}\e[0m"
    end

    def green
      "\e[32m#{self}\e[0m"
    end

    def gray
      "\e[37m#{self}\e[0m"
    end

    def bold
      "\e[1m#{self}\e[0m"
    end

    def clear
      gsub(/\e\[(\d+)m/, '')
    end
  end
end
