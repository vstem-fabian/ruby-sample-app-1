require 'digest'

class User < ActiveRecord::Base
  attr_accessor :password
  attr_accessible :name, :email, :password, :password_confirmation

  has_many :microposts, :dependent => :destroy
  has_many :relationships, :foreign_key => 'follower_id',
                           :dependent => :destroy
  has_many :following, :through => :relationships, :source => :followed
  has_many :reverse_relationships, :foreign_key => 'followed_id',
                                   :class_name  => 'Relationship',
                                   :dependent   => :destroy
  has_many :followers, :through => :reverse_relationships, :source => :follower
  
  email_regex = /\A[\w\+\-\.]+@[a-z\d\-\.]+\.[a-z]+\Z/i

  validates :name, :presence => true,
                   :length => { :maximum => 50 }
  validates :email, :presence => true,
                    :format => { :with => email_regex },
                    :uniqueness => { :case_sensitive => false }
  ## Automatically creates the virtual attribute 'password_confirmation'
  validates :password, :presence => true,
                       :confirmation => true,
                       :length => { :within => 6..40 }
                       
  before_save :encrypt_password
  
  ## Return true if the users's password matches the submitted password
  def has_password?(submitted_password)
    return encrypt(submitted_password) == encrypted_password
  end
  
  def self.authenticate(email, submitted_password)
    user = find_by_email(email)
    return nil if user.nil?
    return user if user.has_password?(submitted_password)
    # else
    return nil
  end
  
  def self.authenticate_with_salt(id, cookie_salt)
    user = find_by_id(id)
    return nil if user.nil?
    return user if cookie_salt == user.salt
    # else, a bad salt
    return nil
  end
  
  def following?(followed)
    relationships.find_by_followed_id(followed)
  end

  def follow!(followed)
    relationships.create!(:followed_id => followed.id)
  end
  
  def unfollow!(followed)
    relationships.find_by_followed_id(followed).destroy
  end
  
  def feed
    # This is preliminary... Full implementation in ch. 12
    Micropost.where('user_id=?', id)
  end
  
  private
    def encrypt_password
      self.salt = make_salt if new_record?
      self.encrypted_password = encrypt(self.password)
    end
    
    def encrypt(str)
      return secure_hash( "#{salt}--#{str}" )
    end
    
    def make_salt
      secure_hash( "#{Time.now.utc}--#{password}")
    end
    
    def secure_hash(str)
      Digest::SHA2.hexdigest(str)
    end
end
