#!/usr/bin/env ruby
# Tạo/cập nhật flavor iOS `staff` và `customer` cho ios/Runner.xcodeproj (idempotent).
# Chạy: gem install xcodeproj && ruby tool/setup_ios_flavors.rb
# Mỗi flavor có 3 cấu hình `Debug-<f>`, `Release-<f>`, `Profile-<f>` + scheme cùng tên (Flutter yêu cầu đúng quy ước này).
# Cấu hình gốc Debug/Release/Profile và scheme Runner được giữ nguyên (= app nhân viên) để lệnh cũ không gãy.
require 'xcodeproj'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
PROJ = File.join(ROOT, 'ios/Runner.xcodeproj')
FLAVORS = {
  'staff' => { bundle: 'vn.corecd.coreCdMobile', name: 'CCTG Nhân viên', icon: 'AppIcon' },
  'customer' => { bundle: 'vn.corecd.customer', name: 'CCTG', icon: 'AppIcon-customer' },
}.freeze
BASES = { 'Debug' => :debug, 'Release' => :release, 'Profile' => :release }.freeze

project = Xcodeproj::Project.open(PROJ)

([project] + project.targets).each do |holder|
  FLAVORS.each_key do |flavor|
    BASES.each do |base, type|
      name = "#{base}-#{flavor}"
      next if holder.build_configurations.any? { |c| c.name == name }
      holder.add_build_configuration(name, type)
    end
  end
end

# Chép cài đặt từ cấu hình gốc sang cấu hình flavor, rồi ghi đè phần riêng của flavor.
([project] + project.targets).each do |holder|
  list = holder.build_configuration_list
  FLAVORS.each do |flavor, cfg|
    BASES.each_key do |base|
      src = list.build_configurations.find { |c| c.name == base }
      dst = list.build_configurations.find { |c| c.name == "#{base}-#{flavor}" }
      next unless src && dst
      dst.build_settings = src.build_settings.dup
      dst.base_configuration_reference = src.base_configuration_reference
      if holder.respond_to?(:name) && holder.name == 'Runner'
        dst.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = cfg[:bundle]
        dst.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = cfg[:icon]
        dst.build_settings['APP_DISPLAY_NAME'] = cfg[:name]
      elsif holder.respond_to?(:name) && holder.name == 'RunnerTests'
        dst.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{cfg[:bundle]}.RunnerTests"
      end
    end
  end
end

# Cấu hình gốc = app nhân viên: cũng đặt tên hiển thị để Info.plist dùng chung biến $(APP_DISPLAY_NAME).
runner = project.targets.find { |t| t.name == 'Runner' }
BASES.each_key do |base|
  c = runner.build_configuration_list.build_configurations.find { |x| x.name == base }
  c.build_settings['APP_DISPLAY_NAME'] = FLAVORS['staff'][:name]
end

# Asset catalog của icon app khách được thêm vào nhóm Runner (file nằm trong Assets.xcassets nên Xcode tự nhận).
project.save

# Scheme: sao chép Runner.xcscheme, đổi tên cấu hình build.
schemes = File.join(PROJ, 'xcshareddata/xcschemes')
template = File.read(File.join(schemes, 'Runner.xcscheme'))
FLAVORS.each_key do |flavor|
  body = template.gsub(/buildConfiguration = "(Debug|Release|Profile)"/) { "buildConfiguration = \"#{$1}-#{flavor}\"" }
  File.write(File.join(schemes, "#{flavor}.xcscheme"), body)
end

# Info.plist dùng biến để đổi tên theo flavor.
plist = File.join(ROOT, 'ios/Runner/Info.plist')
text = File.read(plist)
text.sub!(%r{(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)}, '\1$(APP_DISPLAY_NAME)\2')
text.sub!(%r{(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)}, '\1$(APP_DISPLAY_NAME)\2')
File.write(plist, text)
puts 'OK: đã cấu hình flavor staff/customer'
