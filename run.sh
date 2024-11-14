docker run -d \
  --name s3fs \
  --privileged \
  -e AWS_ACCESS_KEY_ID=your_access_key \
  -e AWS_SECRET_ACCESS_KEY=your_secret_key \
  -e S3_BUCKET=your_bucket_name \
  -e MOUNT_POINT=/mnt/s3 \
  s3fs-container
