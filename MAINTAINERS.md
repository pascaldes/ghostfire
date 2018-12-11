# Warnings 

Because of the way our CICD is setup.

1) Never merge EDGE into MASTER, this would break the .travis instructions

2) Tag only from the master branch (the Ghost versions)

# CICD setup details

The EDGE tag is getting deployed in real time in few websites in  PROD. Those site are site own by FirePress and are used as our End-to-End testing suite.

When those sites are PASSED, we MANUALLY replicate the Dockerfile from EDGE into MASTER. Again, we do this because don’t want to merge/squashed our .travis configurations.

The main delta between EDGE and MASTER is the docker image tagging.

This was specialy necessary when upgrading from Ghost v1.0 to v2.0

So far, we are very happy with this setup.