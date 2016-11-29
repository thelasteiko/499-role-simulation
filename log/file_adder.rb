
open("retrain_20161126.csv", 'a') do |f1|
  i = 0
  IO.foreach("retrain_20161127.csv") { |f2|  f1.puts f2 if i != 0; i += 1}
end