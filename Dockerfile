FROM jekyll:minimal

RUN gem install jekyll-sitemap

COPY . /srv/jekyll