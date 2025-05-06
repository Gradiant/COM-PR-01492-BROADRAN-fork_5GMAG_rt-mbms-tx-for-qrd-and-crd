FROM ubuntu:20.04

RUN ln -snf /usr/share/zoneinfo/Europe/Madrid /etc/localtime 
RUN apt-get update && \
    apt-get install -y \
        ssh g++ git cmake libboost-atomic-dev libboost-thread-dev \
        libboost-system-dev libboost-date-time-dev libboost-regex-dev \ 
        libboost-filesystem-dev libboost-random-dev libboost-chrono-dev \
        libboost-serialization-dev libwebsocketpp-dev openssl libssl-dev ninja-build \
        libspdlog-dev libmbedtls-dev libboost-all-dev libconfig++-dev libsctp-dev \
        libfftw3-dev vim libcpprest-dev libusb-1.0-0-dev net-tools smcroute python3-pip \
        clang-tidy gpsd gpsd-clients libgps-dev ffmpeg libuhd-dev uhd-host libuhd-dev sudo
RUN pip3 install cpplint psutil
RUN apt-get install -y libsoapysdr-dev soapysdr-tools

RUN sudo uhd_images_downloader

# Install BladeRF firmware
RUN apt-get install -y soapysdr-module-bladerf && \
    bladeRF-install-firmware

#Building tx-qrd-crd------
RUN mkdir -p /opt/build/rt-mbms-tx-for-qrd-and-crd
WORKDIR /opt/build/rt-mbms-tx-for-qrd-and-crd

# Clone repo
RUN git clone --recurse-submodules https://github.com/5G-MAG/rt-mbms-tx-for-qrd-and-crd.git . && \
    git submodule update

RUN mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr -GNinja .. && \
    ninja && \
    ninja install && \
    ./srsran_install_configs.sh user 

RUN cp sib.conf.mbsfn /root/.config/srsran/sib.conf.mbsfn && \
    cp Config-Template/enb.conf /root/.config/srsran/enb.conf && \
    cp Config-Template/epc.conf /root/.config/srsran/epc.conf && \
    cp Config-Template/rr.conf /root/.config/srsran/rr.conf 

COPY full_hd.mp4 /root/Big-Buck-Bunny/BigBuckBunny480p30s.mp4
RUN mkdir -p /root/scripts

RUN echo '#!/bin/bash\n\
cd /opt/build/rt-mbms-tx-for-qrd-and-crd/build\n\
./srsepc/src/srsmbms /root/.config/srsran/mbms.conf &\n\
route add -net 239.11.4.0 netmask 255.255.255.0 dev sgi_mb &' > /root/scripts/srsmbms.sh && \
chmod +x /root/scripts/srsmbms.sh

RUN echo '#!/bin/bash\n\
cd /opt/build/rt-mbms-tx-for-qrd-and-crd/build\n\
./srsepc/src/srsepc /root/.config/srsran/epc.conf --hss.db_file /root/.config/srsran/user_db.csv &' > /root/scripts/srsepc.sh && \
chmod +x /root/scripts/srsepc.sh

RUN echo '#!/bin/bash\n\
cd /opt/build/rt-mbms-tx-for-qrd-and-crd/build\n\
./srsenb/src/srsenb /root/.config/srsran/enb.conf --enb_files.sib_config /root/.config/srsran/sib.conf.mbsfn --rf.tx_gain 50' > /root/scripts/srsenb.sh && \
chmod +x /root/scripts/srsenb.sh

RUN echo '#!/bin/bash\n\
ffmpeg -stream_loop -1 -re -i /root/Big-Buck-Bunny/BigBuckBunny480p30s.mp4 -vcodec copy -an -f rtp_mpegts udp://239.11.4.50:9988' > /root/scripts/ffmpeg.sh && \
chmod +x /root/scripts/ffmpeg.sh

CMD ["bash", "-c", "\
  SoapySDRUtil --find && \
  cd /root/.config/srsran &&\
  chmod 777 -R . && \
  /root/scripts/srsmbms.sh && \
  /root/scripts/srsepc.sh &&\
  /root/scripts/srsenb.sh & \
  /root/scripts/ffmpeg.sh"]



