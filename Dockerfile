FROM ubuntu:12.04

ADD . /src/build
RUN chmod +x /src/build/install.sh
RUN /src/build/install.sh

EXPOSE 80
EXPOSE 22

CMD ["/src/build/start.sh"]
