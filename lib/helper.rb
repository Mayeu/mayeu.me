include Nanoc::Helpers::LinkTo

def stylesheet_tag(stylesheet_name)
  '<link rel="stylesheet" href="/style/'+stylesheet_name+'.css" type="text/css" media="screen" charset="utf-8" />'
end

def javascript_tag(javascript_name)
  '<script type="text/javascript" charset="utf-8" src="/js/'+javascript_name+'.js"></script>'
end

def image_tag(image_name, options)
  options_string = ''

  if options[:width]
    options_string << ' width="' + options[:width].to_s + '"'
  end

  if options[:class]
    options_string << ' class="' + options[:class] + '"'
  end

  '<img src="/img/'+image_name+'" '+options_string+' />'
end
